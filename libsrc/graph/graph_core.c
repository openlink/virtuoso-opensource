/*
 *  graph_core.c
 *
 *  Core graph operations and lifecycle
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
#include <stdio.h>

#include "Dk.h"

/* POSIX mmap support - guarded for portability */
#if !defined(GRAPH_OS_WINDOWS) && (defined(GRAPH_OS_LINUX) || defined(GRAPH_OS_MACOS))
#define GRAPH_HAS_MMAP 1
#include <sys/mman.h>
#endif

/* ============================================================================
 * DEFAULT ALLOCATOR
 *
 * The default allocator routes through dk_alloc/dk_free so that even the
 * fallback path (used when no explicit allocator is configured) obeys
 * Virtuoso memory accounting.
 * ============================================================================ */

static void *
default_alloc (size_t size, void *ctx)
{
  (void) ctx;
  return dk_alloc (size);
}

static void *
default_realloc (void *ptr, size_t old_size, size_t new_size, void *ctx)
{
  void *replacement;
  (void) ctx;
  if (!ptr)
    return dk_alloc (new_size);
  replacement = dk_alloc (new_size);
  if (!replacement)
    return NULL;
  memcpy (replacement, ptr, old_size < new_size ? old_size : new_size);
  dk_free (ptr, old_size);
  return replacement;
}

static void
default_free (void *ptr, size_t size, void *ctx)
{
  (void) ctx;
  if (ptr)
    dk_free (ptr, size);
}

const graph_allocator_t GRAPH_DEFAULT_ALLOCATOR = {
  .alloc = default_alloc,
  .realloc = default_realloc,
  .free = default_free,
  .ctx = NULL
};

/* ============================================================================
 * DEFAULT CONFIGURATION
 * ============================================================================ */

const graph_config_t GRAPH_CONFIG_DEFAULT = {
  .initial_node_capacity = GRAPH_INITIAL_NODE_CAPACITY,
  .initial_triple_capacity = GRAPH_INITIAL_TRIPLE_CAPACITY,
  .initial_predicate_capacity = GRAPH_INITIAL_PRED_CAPACITY,
  .build_inverse_index = true,
  .track_predicate_stats = true,
  .allocator = {
	.alloc = default_alloc,
	.realloc = default_realloc,
	.free = default_free,
      .ctx = NULL},
  .use_mmap = false,
  .mmap_path = NULL
};

/* ============================================================================
 * DEFAULT EXECUTION CONTEXT
 * ============================================================================ */

const graph_exec_ctx_t GRAPH_EXEC_DEFAULT = {
  .mode = GRAPH_EXEC_AUTO,
  .num_threads = 0,
  .gpu_device_id = -1,
  .convergence_eps = 1e-6,
  .max_iterations = 100
};

/* ============================================================================
 * DEFAULT WEIGHT FUNCTION
 * ============================================================================ */

static double
uniform_weight (graph_node_id_t s, graph_pred_id_t p, graph_node_id_t o, void *user_data)
{
  (void) s;
  (void) p;
  (void) o;
  (void) user_data;
  return 1.0;
}

const graph_weight_func_t GRAPH_WEIGHT_UNIFORM = uniform_weight;

/* ============================================================================
 * ERROR STRINGS
 * ============================================================================ */

const char *
graph_error_string (graph_error_t err)
{
  switch (err)
    {
    case GRAPH_OK:
      return "Success";
    case GRAPH_ERR_NULL_PTR:
      return "Null pointer";
    case GRAPH_ERR_INVALID_ID:
      return "Invalid ID";
    case GRAPH_ERR_INVALID_PARAM:
      return "Invalid parameter";
    case GRAPH_ERR_OUT_OF_RANGE:
      return "Out of range";
    case GRAPH_ERR_DIMENSION_MISMATCH:
      return "Dimension mismatch";
    case GRAPH_ERR_NOT_INITIALIZED:
      return "Not initialized";
    case GRAPH_ERR_ALREADY_INIT:
      return "Already initialized";
    case GRAPH_ERR_SNAPSHOT_ACTIVE:
      return "Snapshot still active";
    case GRAPH_ERR_NO_SNAPSHOT:
      return "No snapshot";
    case GRAPH_ERR_STALE_SNAPSHOT:
      return "Stale snapshot";
    case GRAPH_ERR_WRITE_LOCKED:
      return "Write locked";
    case GRAPH_ERR_READ_LOCKED:
      return "Read locked";
    case GRAPH_ERR_OUT_OF_MEMORY:
      return "Out of memory";
    case GRAPH_ERR_CAPACITY_EXCEEDED:
      return "Capacity exceeded";
    case GRAPH_ERR_IO_ERROR:
      return "I/O error";
    case GRAPH_ERR_MMAP_FAILED:
      return "Memory map failed";
    case GRAPH_ERR_NOT_FOUND:
      return "Not found";
    case GRAPH_ERR_NO_WEIGHTS:
      return "the weight predicate matched no edges in this graph, so "
	  "every edge would take the default weight of 1.0 and the "
	  "answer would be the unweighted one; check the predicate "
	  "IRI, and that the weights are reified in the same graph "
	  "as the edges (an n-ary :from/:to shape is not read -- the " "reader finds endpoints through rdf:subject/rdf:object)";
    case GRAPH_ERR_ALREADY_EXISTS:
      return "Already exists";
    case GRAPH_ERR_CORRUPTED:
      return "Data corrupted";
    case GRAPH_ERR_VERSION_MISMATCH:
      return "Version mismatch";
      /* Same text as GRAPH_ERR_NOT_FOUND on purpose: see graph.h. */
    case GRAPH_ERR_PERMISSION_DENIED:
      return "Not found";
    case GRAPH_ERR_NO_PATH:
      return "No path exists";
    case GRAPH_ERR_NEGATIVE_CYCLE:
      return "Negative cycle detected";
    case GRAPH_ERR_NOT_CONNECTED:
      return "Graph not connected";
    case GRAPH_ERR_CONVERGENCE:
      return "Failed to converge";
    case GRAPH_ERR_WORKSPACE_TOO_SMALL:
      return "Workspace too small";
    case GRAPH_ERR_GPU_UNAVAILABLE:
      return "GPU unavailable";
    case GRAPH_ERR_GPU_INIT_FAILED:
      return "GPU initialization failed";
    case GRAPH_ERR_GPU_KERNEL_FAILED:
      return "GPU kernel failed";
    case GRAPH_ERR_NOT_IMPLEMENTED:
      return "Not implemented";
    case GRAPH_ERR_NOT_READY:
      return "Not ready";
    default:
      return "Unknown error";
    }
}

/* ============================================================================
 * VERSION AND BUILD INFO
 * ============================================================================ */

const char *
graph_version (void)
{
  return GRAPH_VERSION_STRING;
}

int
graph_build_info (char *buffer, int buffer_size)
{
  if (!buffer || buffer_size <= 0)
    return 0;

  const char *arch = "unknown";
  const char *os = "unknown";

#ifdef GRAPH_ARCH_X64
  arch = "x86_64";
#elif defined(GRAPH_ARCH_ARM64)
  arch = "ARM64";
#endif

#ifdef GRAPH_OS_LINUX
  os = "Linux";
#elif defined(GRAPH_OS_MACOS)
  os = "macOS";
#elif defined(GRAPH_OS_WINDOWS)
  os = "Windows";
#endif

  return snprintf (buffer, buffer_size,
      "Graph Library v%s\n"
      "  Architecture: %s\n"
      "  OS: %s\n"
      "  Cache line: %d bytes\n" "  Page size: %d bytes\n", GRAPH_VERSION_STRING, arch, os, GRAPH_CACHE_LINE_SIZE, GRAPH_PAGE_SIZE);
}

/* ============================================================================
 * NODE INDEX OPERATIONS
 * ============================================================================ */

static uint64_t
next_power_of_two (uint64_t n)
{
  n--;
  n |= n >> 1;
  n |= n >> 2;
  n |= n >> 4;
  n |= n >> 8;
  n |= n >> 16;
  n |= n >> 32;
  n++;
  return n;
}

graph_error_t
graph_node_index_init (graph_node_index_t *idx, const graph_allocator_t *a, uint64_t initial_capacity)
{
  if (!idx || !a)
    return GRAPH_ERR_NULL_PTR;

  uint64_t capacity = next_power_of_two (GRAPH_MAX (initial_capacity, 16));

  size_t size = capacity * sizeof (graph_node_slot_t);
  idx->slots = graph_alloc (a, size);
  if (!idx->slots)
    return GRAPH_ERR_OUT_OF_MEMORY;

  memset (idx->slots, 0, size);
  idx->slot_count = capacity;
  idx->slot_used = 0;
  idx->slot_mask = capacity - 1;

  return GRAPH_OK;
}

void
graph_node_index_destroy (graph_node_index_t *idx, const graph_allocator_t *a)
{
  if (!idx || !a)
    return;

  if (idx->slots)
    {
      graph_free (a, idx->slots, idx->slot_count * sizeof (graph_node_slot_t));
      idx->slots = NULL;
    }
  idx->slot_count = 0;
  idx->slot_used = 0;
}

graph_node_slot_t *
graph_node_index_find (graph_node_index_t *idx, graph_node_id_t node_id)
{
  if (!idx || !idx->slots || node_id == GRAPH_NODE_ID_INVALID)
    return NULL;

  uint64_t hash = graph_hash_u64 (node_id);
  uint64_t slot_idx = hash & idx->slot_mask;
  uint64_t probe = 0;

  while (probe < idx->slot_count)
    {
      graph_node_slot_t *slot = &idx->slots[slot_idx];

      if (slot->node_id == GRAPH_NODE_ID_INVALID)
	{
	  return NULL;
	}
      if (slot->node_id == node_id)
	{
	  return slot;
	}

      probe++;
      slot_idx = (slot_idx + 1) & idx->slot_mask;
    }

  return NULL;
}

graph_error_t
graph_node_index_grow (graph_node_index_t *idx, const graph_allocator_t *a)
{
  if (!idx || !a)
    return GRAPH_ERR_NULL_PTR;

  uint64_t new_count = idx->slot_count * GRAPH_GROWTH_FACTOR;
  size_t new_size = new_count * sizeof (graph_node_slot_t);

  graph_node_slot_t *new_slots = graph_alloc (a, new_size);
  if (!new_slots)
    return GRAPH_ERR_OUT_OF_MEMORY;

  memset (new_slots, 0, new_size);
  uint64_t new_mask = new_count - 1;

  for (uint64_t i = 0; i < idx->slot_count; i++)
    {
      graph_node_slot_t *old_slot = &idx->slots[i];
      if (old_slot->node_id == GRAPH_NODE_ID_INVALID)
	continue;

      uint64_t hash = graph_hash_u64 (old_slot->node_id);
      uint64_t slot_idx = hash & new_mask;

      while (new_slots[slot_idx].node_id != GRAPH_NODE_ID_INVALID)
	{
	  slot_idx = (slot_idx + 1) & new_mask;
	}

      new_slots[slot_idx] = *old_slot;
    }

  graph_free (a, idx->slots, idx->slot_count * sizeof (graph_node_slot_t));
  idx->slots = new_slots;
  idx->slot_count = new_count;
  idx->slot_mask = new_mask;

  return GRAPH_OK;
}

graph_error_t
graph_node_index_insert (graph_node_index_t *idx, const graph_allocator_t *a, graph_node_id_t node_id, graph_node_slot_t **out_slot)
{
  if (!idx || !a)
    return GRAPH_ERR_NULL_PTR;
  if (node_id == GRAPH_NODE_ID_INVALID)
    return GRAPH_ERR_INVALID_ID;

  if ((double) idx->slot_used / idx->slot_count > GRAPH_HASH_LOAD_FACTOR)
    {
      graph_error_t err = graph_node_index_grow (idx, a);
      if (err != GRAPH_OK)
	return err;
    }

  uint64_t hash = graph_hash_u64 (node_id);
  uint64_t slot_idx = hash & idx->slot_mask;

  while (idx->slots[slot_idx].node_id != GRAPH_NODE_ID_INVALID)
    {
      if (idx->slots[slot_idx].node_id == node_id)
	{
	  if (out_slot)
	    *out_slot = &idx->slots[slot_idx];
	  return GRAPH_OK;
	}
      slot_idx = (slot_idx + 1) & idx->slot_mask;
    }

  idx->slots[slot_idx].node_id = node_id;
  idx->slots[slot_idx].edge_offset = 0;
  idx->slots[slot_idx].edge_count = 0;
  idx->slots[slot_idx].inv_offset = 0;
  idx->slots[slot_idx].inv_count = 0;
  idx->slot_used++;

  if (out_slot)
    *out_slot = &idx->slots[slot_idx];
  return GRAPH_OK;
}

/* ============================================================================
 * PREDICATE REGISTRY
 * ============================================================================ */

graph_error_t
graph_pred_registry_init (graph_pred_registry_t *reg, const graph_allocator_t *a, uint64_t initial_capacity, bool track_stats)
{
  if (!reg || !a)
    return GRAPH_ERR_NULL_PTR;

  reg->capacity = GRAPH_MAX (initial_capacity, 16);
  reg->count = 0;
  reg->track_stats = track_stats;

  size_t size = reg->capacity * sizeof (graph_pred_entry_t);
  reg->entries = graph_alloc (a, size);
  if (!reg->entries)
    return GRAPH_ERR_OUT_OF_MEMORY;

  memset (reg->entries, 0, size);
  return GRAPH_OK;
}

void
graph_pred_registry_destroy (graph_pred_registry_t *reg, const graph_allocator_t *a)
{
  if (!reg || !a)
    return;

  if (reg->entries)
    {
      graph_free (a, reg->entries, reg->capacity * sizeof (graph_pred_entry_t));
      reg->entries = NULL;
    }
  reg->capacity = 0;
  reg->count = 0;
}

graph_error_t
graph_pred_registry_record (graph_pred_registry_t *reg, const graph_allocator_t *a, graph_pred_id_t pred_id, int64_t count_delta)
{
  if (!reg || !a)
    return GRAPH_ERR_NULL_PTR;
  if (!reg->track_stats)
    return GRAPH_OK;

  for (uint64_t i = 0; i < reg->count; i++)
    {
      if (reg->entries[i].pred_id == pred_id)
	{
	  reg->entries[i].triple_count = (uint64_t) ((int64_t) reg->entries[i].triple_count + count_delta);
	  return GRAPH_OK;
	}
    }

  if (count_delta <= 0)
    return GRAPH_OK;

  if (reg->count >= reg->capacity)
    {
      uint64_t new_cap = reg->capacity * GRAPH_GROWTH_FACTOR;
      size_t old_size = reg->capacity * sizeof (graph_pred_entry_t);
      size_t new_size = new_cap * sizeof (graph_pred_entry_t);

      graph_pred_entry_t *new_entries = graph_realloc (a, reg->entries, old_size, new_size);
      if (!new_entries)
	return GRAPH_ERR_OUT_OF_MEMORY;

      reg->entries = new_entries;
      reg->capacity = new_cap;
    }

  reg->entries[reg->count].pred_id = pred_id;
  reg->entries[reg->count].triple_count = (uint64_t) count_delta;
  reg->entries[reg->count].first_seen_delta = 0;
  reg->count++;

  return GRAPH_OK;
}

/* ============================================================================
 * BASE STORE OPERATIONS
 * ============================================================================ */

graph_error_t
graph_base_create (graph_base_store_t **out_base,
    const graph_allocator_t *a,
    uint64_t node_capacity, uint64_t edge_capacity, bool build_inverse, bool one_pred, graph_pred_id_t the_pred)
{
  if (!out_base || !a)
    return GRAPH_ERR_NULL_PTR;

  graph_base_store_t *base = graph_alloc (a, sizeof (graph_base_store_t));
  if (!base)
    return GRAPH_ERR_OUT_OF_MEMORY;

  memset (base, 0, sizeof (*base));
  base->magic = GRAPH_BASE_MAGIC;
  /* Never handed out twice, so that "the same CSR" is a question with an
   * exact answer.  Wrapping would take 2^64 compactions. */
  base->build_id = ++graph_base_build_seq;
  base->node_capacity = GRAPH_MAX (node_capacity, 16);
  base->edge_capacity = GRAPH_MAX (edge_capacity, 64);
  base->has_inverse = build_inverse;
  /* One predicate on every edge means no edge records at all -- see
   * graph_base_store_t.  The switch is read here, once per store. */
  base->one_pred = one_pred && graph_one_pred_store;
  base->the_pred = base->one_pred ? the_pred : 0;

  /* The endpoint index width, decided here and nowhere else.
   *
   * From node_capacity rather than node_count because the count is not
   * known yet and a store never grows past the capacity it was created
   * with -- there is no graph_base_grow().  An index is bounded by the
   * node count, so a capacity that fits in 32 bits guarantees every
   * index in this store does. */
  base->narrow_ix = graph_narrow_edge_index && base->node_capacity <= UINT32_MAX;

  base->node_ids = graph_alloc (a, base->node_capacity * sizeof (graph_node_id_t));
  base->edge_offsets = graph_alloc (a, (base->node_capacity + 1) * sizeof (uint64_t));
  base->edges = base->one_pred ? NULL : graph_alloc (a, base->edge_capacity * sizeof (graph_edge_t));
  base->edge_targets = graph_alloc (a, base->edge_capacity * GRAPH_IX_SIZE (base->narrow_ix));

  if (!base->node_ids || !base->edge_offsets || (!base->one_pred && !base->edges) || !base->edge_targets)
    {
      graph_base_destroy (base, a);
      return GRAPH_ERR_OUT_OF_MEMORY;
    }

  base->edge_offsets[0] = 0;

  if (build_inverse)
    {
      base->inv_offsets = graph_alloc (a, (base->node_capacity + 1) * sizeof (uint64_t));
      base->inv_edges = base->one_pred ? NULL : graph_alloc (a, base->edge_capacity * sizeof (graph_inverse_edge_t));
      base->inv_sources = graph_alloc (a, base->edge_capacity * GRAPH_IX_SIZE (base->narrow_ix));

      if (!base->inv_offsets || (!base->one_pred && !base->inv_edges) || !base->inv_sources)
	{
	  graph_base_destroy (base, a);
	  return GRAPH_ERR_OUT_OF_MEMORY;
	}
      base->inv_offsets[0] = 0;
    }

  *out_base = base;
  return GRAPH_OK;
}

void
graph_base_destroy (graph_base_store_t *base, const graph_allocator_t *a)
{
  if (!base || !a)
    return;

  if (base->is_mmap)
    {
#ifdef GRAPH_HAS_MMAP
      if (base->mmap_base)
	{
	  munmap (base->mmap_base, base->mmap_size);
	}
#endif
    }
  else
    {
      if (base->node_ids)
	{
	  graph_free (a, base->node_ids, base->node_capacity * sizeof (graph_node_id_t));
	}
      if (base->edge_offsets)
	{
	  graph_free (a, base->edge_offsets, (base->node_capacity + 1) * sizeof (uint64_t));
	}
      if (base->edges)
	{
	  graph_free (a, base->edges, base->edge_capacity * sizeof (graph_edge_t));
	}
      if (base->edge_targets)
	{
	  graph_free (a, base->edge_targets, base->edge_capacity * GRAPH_IX_SIZE (base->narrow_ix));
	}
      if (base->inv_offsets)
	{
	  graph_free (a, base->inv_offsets, (base->node_capacity + 1) * sizeof (uint64_t));
	}
      if (base->inv_edges)
	{
	  graph_free (a, base->inv_edges, base->edge_capacity * sizeof (graph_inverse_edge_t));
	}
      if (base->inv_sources)
	{
	  graph_free (a, base->inv_sources, base->edge_capacity * GRAPH_IX_SIZE (base->narrow_ix));
	}
    }

  graph_free (a, base, sizeof (graph_base_store_t));
}

/* Whether a store built from here may use the arithmetic path.  Off forces
 * the search, so the suite can run the same question down both and require
 * the same answer; there is no other way to compare them.  It is read when
 * the store is built, not per lookup, so flipping it takes effect on the
 * next build -- which is what bumping the cache generation arranges. */
bool graph_dense_node_index = true;
void
graph_base_set_dense_index (bool on)
{
  graph_dense_node_index = on;
}

bool
graph_base_dense_index (void)
{
  return graph_dense_node_index;
}

/* Whether a store built from here narrows its endpoint index arrays to 32
 * bits.  Off forces 8 bytes an entry, for the same reason the dense switch
 * exists: the two widths must be comparable on the same question, and the
 * answers are identical either way so nothing but a switch can tell them
 * apart.  Read when the store is allocated, so a change takes effect on
 * the next build -- which is what bumping the cache generation arranges. */
/* Assigned to every store graph_base_create() makes.  Not atomic: a store
 * is created under the caller's own lock or before it is published, and a
 * duplicate id would only cost a needless array rebuild, never a wrong
 * answer -- but see the comment on build_id for why a *reused* id would. */
uint64_t graph_base_build_seq = 0;

bool graph_narrow_edge_index = true;
void
graph_base_set_narrow_index (bool on)
{
  graph_narrow_edge_index = on;
}

bool
graph_base_narrow_index (void)
{
  return graph_narrow_edge_index;
}

/* Whether a store whose edges all carry one predicate may drop the edge
 * records.  Off keeps them, which is the only way the suite can ask one
 * question of both shapes.  Read when the store is allocated, so the
 * generation bump is what makes a change take effect. */
bool graph_one_pred_store = true;
void
graph_base_set_one_pred_store (bool on)
{
  graph_one_pred_store = on;
}

bool
graph_base_one_pred_store (void)
{
  return graph_one_pred_store;
}

uint64_t
graph_base_find_node_index (const graph_base_store_t *base, graph_node_id_t node_id)
{
  return graph_base_node_index (base, node_id);
}

/* Decide, once per store, whether its ids are a contiguous run.  Called
 * from every place that fills node_ids; a store that never calls it keeps
 * the zeroed descriptor and takes the search path, which is correct but
 * slow, so the call belongs beside the fill rather than in one loader. */
void
graph_base_set_dense_descriptor (graph_base_store_t *base)
{
  if (!base)
    return;
  base->dense_base = base->node_count ? base->node_ids[0] : 0;
  base->dense_ids = graph_dense_node_index && base->node_count > 0 &&
      (base->node_ids[base->node_count - 1] - base->node_ids[0] == base->node_count - 1);
}

/* Fill edge_targets / inv_sources from the adjacency arrays.
 *
 * graph_compact() writes them as it places each edge, so it does not need
 * this.  A store loaded from a file does: the on-disk format carries
 * node_ids, the offsets and the edges, and has never carried the endpoint
 * indices, so without this the arrays hold whatever the allocator left
 * there.  Rebuilding is one node-index lookup per edge -- the same lookup
 * the build does -- and it is what makes a loaded store answer the same
 * questions as a compacted one.
 *
 * Returns false, having done nothing, if the store has no arrays to fill;
 * the neighbour iterator declines the index arrays in that case rather
 * than reading them, so a loaded store is slow but not wrong. */
bool
graph_base_rebuild_edge_indices (graph_base_store_t *base)
{
  uint64_t i, at;
  if (!base || !base->node_count)
    return false;
  if (!base->edge_targets || !base->edges)
    return false;
  if (base->has_inverse && (!base->inv_sources || !base->inv_edges))
    return false;
  for (i = 0; i < base->node_count; i++)
    {
      for (at = base->edge_offsets[i]; at < base->edge_offsets[i + 1]; at++)
	graph_ix_set (base->edge_targets, base->narrow_ix, at, graph_base_node_index (base, base->edges[at].object));
    }
  if (base->has_inverse)
    {
      for (i = 0; i < base->node_count; i++)
	{
	  for (at = base->inv_offsets[i]; at < base->inv_offsets[i + 1]; at++)
	    graph_ix_set (base->inv_sources, base->narrow_ix, at, graph_base_node_index (base, base->inv_edges[at].subject));
	}
    }
  return true;
}




/* The same rows, addressed by node index rather than by node id.  A
 * traversal that already holds the index -- which after the neighbour
 * iterator hands one back for every edge, is all of them -- would
 * otherwise pay graph_base_find_node_index() to search a sorted table of
 * every node id for something it already knows: 20 levels over 5 MB at
 * 633,432 nodes, once per vertex visited. */
graph_error_t
graph_base_get_edges_at (const graph_base_store_t *base,
    uint64_t idx, uint64_t *out_start, const void **out_target_ix, uint32_t *out_count)
{
  uint64_t start, end;
  if (!base || !out_start || !out_target_ix || !out_count)
    return GRAPH_ERR_NULL_PTR;
  *out_start = 0;
  *out_target_ix = NULL;
  *out_count = 0;
  if (idx >= base->node_count)
    return GRAPH_ERR_NOT_FOUND;
  start = base->edge_offsets[idx];
  end = base->edge_offsets[idx + 1];
  /* The row's first absolute slot rather than a pointer into edges[],
   * because on a one-predicate store there is no edges[] to point into
   * -- and because a slot number is what indexes the endpoint slice and
   * the per-slot weights as well. */
  *out_start = start;
  *out_target_ix = graph_ix_slice (base->edge_targets, base->narrow_ix, start);
  *out_count = (uint32_t) (end - start);
  return GRAPH_OK;
}

graph_error_t
graph_base_get_inverse_edges_at (const graph_base_store_t *base,
    uint64_t idx, uint64_t *out_start, const void **out_source_ix, uint32_t *out_count)
{
  uint64_t start, end;
  if (!base || !out_start || !out_source_ix || !out_count)
    return GRAPH_ERR_NULL_PTR;
  *out_start = 0;
  *out_source_ix = NULL;
  *out_count = 0;
  /* The inverse index exists when its offsets do.  Testing inv_edges
   * here is what it used to be, and a one-predicate store has none. */
  if (!base->has_inverse || !base->inv_offsets || !base->inv_sources)
    return GRAPH_ERR_NOT_FOUND;
  if (idx >= base->node_count)
    return GRAPH_ERR_NOT_FOUND;
  start = base->inv_offsets[idx];
  end = base->inv_offsets[idx + 1];
  *out_start = start;
  *out_source_ix = graph_ix_slice (base->inv_sources, base->narrow_ix, start);
  *out_count = (uint32_t) (end - start);
  return GRAPH_OK;
}


/* ============================================================================
 * PER-EDGE WEIGHTS, RESOLVED INTO SLOT ORDER
 * ============================================================================ */

typedef struct base_weight_slice_ctx
{
  const graph_base_store_t *base;
  graph_weight_probe_f probe;
  void *probe_ud;
  bool symmetric;
  double dflt;
  double *fwd;
  double *inv;
} base_weight_slice_ctx_t;

/* Forward pass.  Slot at in node i's row is the edge (node_ids[i], p,
 * edges[at].object), and a traversal leaving that node asks for its weight
 * in exactly that order, so the probe sequence here is the probe sequence
 * the traversal would make -- including the symmetric fallback, which is
 * what makes the array's value identical to the lookup's rather than
 * merely close to it.
 *
 * The probes also arrive in ascending (subject, object), which is the
 * order a table read out of a graph is sorted in, so consecutive searches
 * land near each other and the upper levels of each search stay in cache.
 * That is the difference between this pass and the traversal it replaces:
 * the traversal asks in visit order, which is random. */
static void
base_weight_fwd_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  (void) worker_index;
  base_weight_slice_ctx_t *c = (base_weight_slice_ctx_t *) arg;
  const graph_base_store_t *base = c->base;
  uint64_t i;

  for (i = start; i < end; i++)
    {
      graph_node_id_t u = base->node_ids[i];
      uint64_t at = base->edge_offsets[i];
      uint64_t stop = base->edge_offsets[i + 1];
      for (; at < stop; at++)
	{
	  graph_node_id_t v = graph_base_slot_obj (base, at);
	  double w;
	  if (c->probe (c->probe_ud, u, v, &w))
	    c->fwd[at] = w;
	  else if (c->symmetric && c->probe (c->probe_ud, v, u, &w))
	    c->fwd[at] = w;
	  else
	    c->fwd[at] = c->dflt;
	}
    }
}

/* Inverse pass.  Slot at in node u's inverse row is the edge (w, p, u),
 * and a traversal standing on u asks for weight(u, w) -- the traversal's
 * order, not the edge's.  So the first probe is (u, w), which again
 * ascends across the whole array.
 *
 * When that probe misses and the lookup is symmetric, the answer is
 * weight(w, u) if the table holds it and the default otherwise -- and
 * that is exactly what the forward pass already wrote into the slot of
 * the edge (w, p, u), because that slot's own symmetric fallback probes
 * (u, w), which we have just established misses.  So the value is read out
 * of fwd[] rather than searched for a second time, which is what keeps
 * the one genuinely random search out of this pass.
 *
 * Requires the forward pass to have completed. */
static void
base_weight_inv_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  (void) worker_index;
  base_weight_slice_ctx_t *c = (base_weight_slice_ctx_t *) arg;
  const graph_base_store_t *base = c->base;
  uint64_t i;

  for (i = start; i < end; i++)
    {
      graph_node_id_t u = base->node_ids[i];
      uint64_t at = base->inv_offsets[i];
      uint64_t stop = base->inv_offsets[i + 1];
      for (; at < stop; at++)
	{
	  graph_node_id_t w_node = graph_base_inv_slot_subj (base, at);
	  double w;
	  if (c->probe (c->probe_ud, u, w_node, &w))
	    {
	      c->inv[at] = w;
	      continue;
	    }
	  if (!c->symmetric)
	    {
	      c->inv[at] = c->dflt;
	      continue;
	    }
	  {
	    /* The same edge's forward slot: inv_sources[at] is w's
	     * node index, so the row is found without a node lookup
	     * and the search inside it is over one vertex's degree. */
	    uint64_t wi = graph_ix_at (base->inv_sources, base->narrow_ix, at);
	    uint64_t row = base->edge_offsets[wi];
	    uint32_t deg = (uint32_t) (base->edge_offsets[wi + 1] - row);
	    uint32_t off = graph_base_row_find (base, row, deg,
		graph_base_inv_slot_pred (base, at),
		u);
	    if (off < deg)
	      c->inv[at] = c->fwd[row + off];
	    else
	      c->inv[at] = c->dflt;	/* cannot happen; not worth trusting */
	  }
	}
    }
}

graph_error_t
graph_base_resolve_edge_weights (const graph_base_store_t *base,
    graph_weight_probe_f probe, void *probe_user_data, bool symmetric, double default_weight, double *out_fwd, double *out_inv)
{
  graph_parallel_session_t *par;
  base_weight_slice_ctx_t c;

  if (!base || !probe || !out_fwd)
    return GRAPH_ERR_NULL_PTR;
  if (base->magic != GRAPH_BASE_MAGIC)
    return GRAPH_ERR_CORRUPTED;
  if (out_inv && (!base->has_inverse || !base->inv_offsets || !base->inv_sources))
    return GRAPH_ERR_NOT_FOUND;
  if (!base->edge_count)
    return GRAPH_OK;

  c.base = base;
  c.probe = probe;
  c.probe_ud = probe_user_data;
  c.symmetric = symmetric;
  c.dflt = default_weight;
  c.fwd = out_fwd;
  c.inv = out_inv;

  /* The probe is a read of an immutable sorted table and each slice
   * writes only its own slots, so this satisfies the purity rule the
   * parallel executor requires: no allocation, no lock, no query
   * context.  Slices are node ranges, so a power-law graph divides
   * unevenly -- still much better than one core. */
  par = graph_parallel_begin (base->node_count, GRAPH_PARALLEL_MAX_WORKERS);
  graph_parallel_run (par, 0, base->node_count, base_weight_fwd_slice, &c);
  if (out_inv)
    graph_parallel_run (par, 0, base->node_count, base_weight_inv_slice, &c);
  graph_parallel_end (par);
  return GRAPH_OK;
}

bool
graph_is_triple_deleted (const graph_delta_t *delta_head, const graph_triple_t *triple)
{
  const graph_delta_t *d = delta_head;
  while (d)
    {
      if (graph_delta_contains_deletion (d, triple))
	return true;
      d = d->prev;
    }
  return false;
}

bool
graph_chain_has_deletions (const graph_delta_t *delta_head)
{
  const graph_delta_t *d = delta_head;
  while (d)
    {
      if (d->deletion_count)
	return true;
      d = d->prev;
    }
  return false;
}

bool
graph_base_contains (const graph_base_store_t *base, const graph_triple_t *triple)
{
  uint64_t node_ix, start;
  uint32_t count, at;

  if (!base || !triple || !base->node_count)
    return false;

  node_ix = graph_base_node_index (base, triple->subject);
  if (UINT64_MAX == node_ix)
    return false;

  start = base->edge_offsets[node_ix];
  count = (uint32_t) (base->edge_offsets[node_ix + 1] - start);
  at = graph_base_row_find (base, start, count, triple->predicate, triple->object);
  return at < count && graph_base_slot_is (base, start + at, triple->predicate, triple->object);
}

/* ============================================================================
 * GRAPH LIFECYCLE
 * ============================================================================ */

graph_error_t
graph_create (const graph_config_t *config, graph_t **out_graph)
{
  if (!out_graph)
    return GRAPH_ERR_NULL_PTR;

  const graph_config_t *cfg = config ? config : &GRAPH_CONFIG_DEFAULT;
  const graph_allocator_t *a = &cfg->allocator;

  graph_t *g = graph_alloc (a, sizeof (graph_t));
  if (!g)
    return GRAPH_ERR_OUT_OF_MEMORY;

  memset (g, 0, sizeof (*g));
  g->config = *cfg;
  g->allocator = *a;

  graph_error_t err;

  /* The store a graph starts with is empty and its predicate set is not
   * known, so it keeps the records.  graph_compact() builds the store
   * that matters and decides there. */
  err = graph_base_create (&g->base, a,
      cfg->initial_node_capacity, cfg->initial_triple_capacity, cfg->build_inverse_index, false, 0);
  if (err != GRAPH_OK)
    {
      graph_free (a, g, sizeof (graph_t));
      return err;
    }

  err = graph_node_index_init (&g->node_index, a, cfg->initial_node_capacity);
  if (err != GRAPH_OK)
    {
      graph_base_destroy (g->base, a);
      graph_free (a, g, sizeof (graph_t));
      return err;
    }

  err = graph_pred_registry_init (&g->pred_registry, a, cfg->initial_predicate_capacity, cfg->track_predicate_stats);
  if (err != GRAPH_OK)
    {
      graph_node_index_destroy (&g->node_index, a);
      graph_base_destroy (g->base, a);
      graph_free (a, g, sizeof (graph_t));
      return err;
    }

  err = graph_delta_create (&g->working_delta, a, 0, NULL);
  if (err != GRAPH_OK)
    {
      graph_pred_registry_destroy (&g->pred_registry, a);
      graph_node_index_destroy (&g->node_index, a);
      graph_base_destroy (g->base, a);
      graph_free (a, g, sizeof (graph_t));
      return err;
    }

  g->next_delta_id = 1;
  g->next_snapshot_id = 1;
  g->initialized = true;

  *out_graph = g;
  return GRAPH_OK;
}

graph_error_t
graph_destroy (graph_t *graph)
{
  if (!graph)
    return GRAPH_ERR_NULL_PTR;

  if (graph->snapshot_count > 0)
    {
      return GRAPH_ERR_SNAPSHOT_ACTIVE;
    }

  const graph_allocator_t *a = &graph->allocator;

  graph_delta_t *delta = graph->delta_head;
  while (delta)
    {
      graph_delta_t *prev = delta->prev;
      graph_delta_destroy (delta, a);
      delta = prev;
    }

  if (graph->working_delta)
    {
      graph_delta_destroy (graph->working_delta, a);
    }

  graph_pred_registry_destroy (&graph->pred_registry, a);
  graph_node_index_destroy (&graph->node_index, a);
  graph_base_destroy (graph->base, a);

  graph->initialized = false;
  graph_free (a, graph, sizeof (graph_t));

  return GRAPH_OK;
}

graph_error_t
graph_get_stats (const graph_t *graph, graph_stats_t *out_stats)
{
  if (!graph || !out_stats)
    return GRAPH_ERR_NULL_PTR;

  memset (out_stats, 0, sizeof (*out_stats));

  out_stats->node_count = graph->total_nodes;
  out_stats->triple_count = graph->total_triples;
  out_stats->predicate_count = graph->pred_registry.count;
  out_stats->snapshot_count = graph->snapshot_count;
  out_stats->delta_count = graph->delta_count;

  uint64_t delta_triples = 0;
  graph_delta_t *d = graph->delta_head;
  while (d)
    {
      delta_triples += d->addition_count;
      d = d->prev;
    }
  if (graph->working_delta)
    {
      delta_triples += graph->working_delta->addition_count;
    }
  out_stats->delta_triple_count = delta_triples;

  out_stats->base_store_bytes =
      graph->base->node_count * sizeof (graph_node_id_t) +
      (graph->base->node_count + 1) * sizeof (uint64_t) +
      (graph->base->edges ? graph->base->edge_count * sizeof (graph_edge_t) : 0) +
      graph->base->edge_count * GRAPH_IX_SIZE (graph->base->narrow_ix);

  out_stats->index_bytes = graph->node_index.slot_count * sizeof (graph_node_slot_t);

  out_stats->total_bytes = sizeof (graph_t) + out_stats->base_store_bytes + out_stats->index_bytes;

  if (out_stats->node_count > 0)
    {
      out_stats->avg_out_degree = (double) out_stats->triple_count / out_stats->node_count;
    }

  return GRAPH_OK;
}

/* ============================================================================
 * TRIPLE OPERATIONS
 * ============================================================================ */

graph_error_t
graph_add_triple (graph_t *graph, const graph_triple_t *triple)
{
  if (!graph || !triple)
    return GRAPH_ERR_NULL_PTR;
  if (!graph->initialized)
    return GRAPH_ERR_NOT_INITIALIZED;

  if (triple->subject == GRAPH_NODE_ID_INVALID ||
      triple->predicate == GRAPH_PRED_ID_INVALID || triple->object == GRAPH_NODE_ID_INVALID)
    {
      return GRAPH_ERR_INVALID_ID;
    }

  const graph_allocator_t *a = &graph->allocator;
  graph_error_t err;

  err = graph_delta_add_triple (graph->working_delta, a, triple);
  if (err != GRAPH_OK)
    return err;

  uint64_t nodes_before = graph->node_index.slot_used;

  graph_node_slot_t *slot;
  err = graph_node_index_insert (&graph->node_index, a, triple->subject, &slot);
  if (err != GRAPH_OK)
    return err;

  err = graph_node_index_insert (&graph->node_index, a, triple->object, &slot);
  if (err != GRAPH_OK)
    return err;

  graph->total_nodes += (graph->node_index.slot_used - nodes_before);

  err = graph_pred_registry_record (&graph->pred_registry, a, triple->predicate, 1);
  if (err != GRAPH_OK)
    return err;

  graph->total_triples++;

  return GRAPH_OK;
}

graph_error_t
graph_remove_triple (graph_t *graph, const graph_triple_t *triple)
{
  if (!graph || !triple)
    return GRAPH_ERR_NULL_PTR;
  if (!graph->initialized)
    return GRAPH_ERR_NOT_INITIALIZED;

  const graph_allocator_t *a = &graph->allocator;
  graph_error_t err;

  err = graph_delta_remove_triple (graph->working_delta, a, triple);
  if (err != GRAPH_OK)
    return err;

  graph_pred_registry_record (&graph->pred_registry, a, triple->predicate, -1);

  if (graph->total_triples > 0)
    {
      graph->total_triples--;
    }

  return GRAPH_OK;
}

static int
graph_delta_addition_cmp (const void *pa, const void *pb)
{
  const graph_triple_t *ta = (const graph_triple_t *) pa;
  const graph_triple_t *tb = (const graph_triple_t *) pb;
  if (ta->subject != tb->subject)
    return ta->subject < tb->subject ? -1 : 1;
  if (ta->predicate != tb->predicate)
    return ta->predicate < tb->predicate ? -1 : 1;
  if (ta->object != tb->object)
    return ta->object < tb->object ? -1 : 1;
  return 0;
}

graph_error_t
graph_commit (graph_t *graph)
{
  if (!graph)
    return GRAPH_ERR_NULL_PTR;
  if (!graph->initialized)
    return GRAPH_ERR_NOT_INITIALIZED;

  graph_delta_t *working = graph->working_delta;

  if (working->addition_count == 0 && working->deletion_count == 0)
    {
      return GRAPH_OK;
    }

  const graph_allocator_t *a = &graph->allocator;

  /*
   * Canonicalize the addition order before the delta joins the chain:
   * neighbor iteration walks additions in array order, and algorithms
   * accumulate floating-point state over that order.  Sorting by
   * (subject, predicate, object) makes results a function of the edge
   * set alone, independent of the order triples were loaded in.
   */
  if (working->addition_count > 1)
    qsort (working->additions, working->addition_count, sizeof (graph_triple_t), graph_delta_addition_cmp);

  /* Drop duplicate additions.  graph_delta_add_triple() deliberately does
   * not check for them - doing so per insert made bulk loading quadratic -
   * so the sorted array is deduplicated here instead.  A committed delta
   * is therefore still a set, exactly as before. */
  if (working->addition_count > 1)
    {
      uint32_t r, w = 1;
      for (r = 1; r < working->addition_count; r++)
	{
	  if (0 != graph_delta_addition_cmp (&working->additions[w - 1], &working->additions[r]))
	    working->additions[w++] = working->additions[r];
	}
      if (w != working->addition_count)
	{
	  uint32_t dropped = working->addition_count - w;
	  working->addition_count = w;
	  working->triple_delta -= dropped;
	  if (graph->total_triples >= dropped)
	    graph->total_triples -= dropped;
	}
    }

  working->id = graph->next_delta_id++;
  working->prev = graph->delta_head;

  graph->delta_head = working;
  if (!graph->delta_tail)
    {
      graph->delta_tail = working;
    }
  graph->delta_count++;

  graph_error_t err = graph_delta_create (&graph->working_delta, a, 0, NULL);
  if (err != GRAPH_OK)
    {
      graph->working_delta = working;
      graph->delta_head = working->prev;
      graph->delta_count--;
      if (graph->delta_tail == working)
	{
	  graph->delta_tail = NULL;
	}
      return err;
    }

  return GRAPH_OK;
}

static int graph_delta_addition_cmp (const void *pa, const void *pb);

/* ============================================================================
 * COMPACTION
 *
 * Fold the delta chain into the immutable base store as a pair of CSRs
 * (forward S->(P,O) and inverse O->(P,S)).  Everything the algorithms do
 * hangs off this: without it a row lookup never finds a node,
 * every neighbour lookup falls through to a linear scan of the whole
 * addition array, and a single node's degree costs O(E).
 *
 * Order is preserved exactly.  graph_commit() has already sorted the
 * additions by (subject, predicate, object), and both CSRs are filled by a
 * stable counting pass over that order, so a node's out-neighbours still
 * arrive in ascending (predicate, object) order and its in-neighbours in
 * ascending (subject, predicate) order - the same sequence the delta scan
 * produced.  Iterative algorithms accumulate identically.
 * ============================================================================ */

/* Total additions across the delta chain, oldest last. */
static uint64_t
graph_delta_chain_additions (const graph_delta_t *head)
{
  uint64_t n = 0;
  while (head)
    {
      n += head->addition_count;
      head = head->prev;
    }
  return n;
}

static int
graph_node_id_cmp (const void *pa, const void *pb)
{
  graph_node_id_t a = *(const graph_node_id_t *) pa;
  graph_node_id_t b = *(const graph_node_id_t *) pb;
  return (a < b) ? -1 : (a > b) ? 1 : 0;
}

graph_error_t
graph_compact (graph_t *graph)
{
  const graph_allocator_t *a;
  graph_base_store_t *old_base, *nb = NULL;
  graph_delta_t *d;
  graph_triple_t *triples = NULL;
  graph_node_id_t *nodes = NULL;
  uint64_t *cursor = NULL;
  uint64_t triple_cap = 0, triple_count = 0;
  uint64_t node_cap = 0, node_count = 0;
  uint64_t i;
  bool one_pred = false;
  graph_pred_id_t the_pred = 0;
  graph_error_t err;

  if (!graph)
    return GRAPH_ERR_NULL_PTR;
  if (!graph->initialized)
    return GRAPH_ERR_NOT_INITIALIZED;
  /* Snapshots pin the delta chain; compacting under them would free
   * memory they still read. */
  if (graph->snapshot_count)
    return GRAPH_ERR_SNAPSHOT_ACTIVE;
  if (!graph->delta_head)
    return GRAPH_OK;		/* nothing to fold in */

  a = &graph->allocator;
  old_base = graph->base;

  /* --- 1. Collect base edges + delta additions, minus deletions ------- */
  triple_cap = graph_delta_chain_additions (graph->delta_head);
  if (old_base)
    triple_cap += old_base->edge_count;
  if (!triple_cap)
    return GRAPH_OK;

  triples = graph_alloc (a, triple_cap * sizeof (graph_triple_t));
  if (!triples)
    return GRAPH_ERR_OUT_OF_MEMORY;

  if (old_base && old_base->node_count)
    {
      for (i = 0; i < old_base->node_count; i++)
	{
	  uint64_t start = old_base->edge_offsets[i];
	  uint64_t end = old_base->edge_offsets[i + 1];
	  uint64_t e;
	  for (e = start; e < end; e++)
	    {
	      graph_triple_t t = { old_base->node_ids[i],
		graph_base_slot_pred (old_base, e),
		graph_base_slot_obj (old_base, e)
	      };
	      if (!graph_is_triple_deleted (graph->delta_head, &t))
		triples[triple_count++] = t;
	    }
	}
    }
  /* Newest delta first, matching the order neighbour iteration walked
   * the chain; the sort below makes the merge order irrelevant anyway. */
  for (d = graph->delta_head; d; d = d->prev)
    {
      uint32_t k;
      for (k = 0; k < d->addition_count; k++)
	{
	  /* A deletion recorded in a *newer* delta removes the triple. */
	  if (!graph_is_triple_deleted (graph->delta_head, &d->additions[k]))
	    triples[triple_count++] = d->additions[k];
	}
    }

  if (triple_count > 1)
    qsort (triples, triple_count, sizeof (graph_triple_t), graph_delta_addition_cmp);

  /* --- 2. Unique sorted node set (subjects and objects) --------------- */
  node_cap = triple_count * 2;
  nodes = graph_alloc (a, node_cap * sizeof (graph_node_id_t));
  if (!nodes)
    {
      err = GRAPH_ERR_OUT_OF_MEMORY;
      goto fail;
    }
  for (i = 0; i < triple_count; i++)
    {
      nodes[node_count++] = triples[i].subject;
      nodes[node_count++] = triples[i].object;
    }
  if (node_count > 1)
    qsort (nodes, node_count, sizeof (graph_node_id_t), graph_node_id_cmp);
  {
    uint64_t w = 0;
    for (i = 0; i < node_count; i++)
      if (0 == w || nodes[w - 1] != nodes[i])
	nodes[w++] = nodes[i];
    node_count = w;
  }

  /* --- 3. Allocate the new base store -------------------------------- */
  /* Does every edge carry the same predicate?  One pass over a list that
   * is already in memory, so it costs nothing measurable, and when the
   * answer is yes the store drops both edge-record arrays -- 32 bytes an
   * edge, which at this size is most of it.
   *
   * Asked of the triples rather than taken from how the graph was
   * loaded: a filtered load has one predicate by construction, but an
   * unfiltered load of a graph that only holds one gets the same
   * treatment for the same reason. */
  {
    one_pred = triple_count > 0;
    the_pred = one_pred ? triples[0].predicate : 0;
    for (i = 1; one_pred && i < triple_count; i++)
      if (triples[i].predicate != the_pred)
	one_pred = false;
  }

  err = graph_base_create (&nb, a, node_count, triple_count, graph->config.build_inverse_index, one_pred, the_pred);
  if (err != GRAPH_OK)
    goto fail;
  nb->node_count = node_count;
  nb->edge_count = triple_count;
  memcpy (nb->node_ids, nodes, node_count * sizeof (graph_node_id_t));

  /* Are the ids a contiguous run?  node_ids has just been sorted and
   * deduplicated above, so n distinct values spanning exactly n-1 leaves
   * no room for a gap -- the endpoints settle it, and the six searches
   * per triple below become six subtractions. */
  graph_base_set_dense_descriptor (nb);

  cursor = graph_alloc (a, (node_count + 1) * sizeof (uint64_t));
  if (!cursor)
    {
      err = GRAPH_ERR_OUT_OF_MEMORY;
      goto fail;
    }

  /* --- 4. Forward CSR: bucket by subject, stable in (P,O) order -------
   *
   * The subject index comes from a merge, not a search.  `triples` is
   * sorted by (subject, predicate, object) and node_ids is the sorted
   * unique union of both endpoints, so a cursor walking node_ids beside
   * the triples only ever moves forward: one linear pass over an array
   * that is already in cache, against a binary search into every node id
   * per triple.
   *
   * That leaves the object as the only search here, and step 5 below
   * needs none at all -- six searches per triple down to one.  At
   * 34,185,747 triples the six were about 5 x 10^9 random probes into a
   * 5 MB table, and they are 40% of this build when the ids are not
   * dense enough for graph_base_node_index() to answer by subtraction. */
  memset (nb->edge_offsets, 0, (node_count + 1) * sizeof (uint64_t));
  {
    uint64_t k = 0;		/* merge cursor over node_ids */
    for (i = 0; i < triple_count; i++)
      {
	while (k < node_count && nb->node_ids[k] < triples[i].subject)
	  k++;
	nb->edge_offsets[k + 1]++;
      }
  }
  for (i = 0; i < node_count; i++)
    nb->edge_offsets[i + 1] += nb->edge_offsets[i];
  memcpy (cursor, nb->edge_offsets, node_count * sizeof (uint64_t));
  {
    uint64_t k = 0;
    for (i = 0; i < triple_count; i++)
      {
	uint64_t at;
	while (k < node_count && nb->node_ids[k] < triples[i].subject)
	  k++;
	at = cursor[k]++;
	if (nb->edges)
	  {
	    nb->edges[at].predicate = triples[i].predicate;
	    nb->edges[at].object = triples[i].object;
	  }
	graph_ix_set (nb->edge_targets, nb->narrow_ix, at, graph_base_node_index (nb, triples[i].object));
      }
  }

  /* --- 5. Inverse CSR: bucket by object, stable in (S,P) order --------
   *
   * Built from the forward CSR rather than from `triples`, which is what
   * makes it search-free: the forward CSR holds every edge exactly once,
   * a row number *is* a subject index and edge_targets[at] *is* the
   * object index, so both endpoints are already resolved.
   *
   * The order is the same order.  Walking rows ascending is walking
   * subjects ascending, and within a row the slots are in (predicate,
   * object) order, so each object collects its sources in (subject,
   * predicate) order -- which is exactly what iterating the sorted
   * triples gave. */
  if (nb->has_inverse)
    {
      uint64_t at;
      memset (nb->inv_offsets, 0, (node_count + 1) * sizeof (uint64_t));
      for (i = 0; i < node_count; i++)
	{
	  uint64_t stop = nb->edge_offsets[i + 1];
	  for (at = nb->edge_offsets[i]; at < stop; at++)
	    {
	      uint64_t o = graph_ix_at (nb->edge_targets, nb->narrow_ix, at);
	      nb->inv_offsets[o + 1]++;
	    }
	}
      for (i = 0; i < node_count; i++)
	nb->inv_offsets[i + 1] += nb->inv_offsets[i];
      memcpy (cursor, nb->inv_offsets, node_count * sizeof (uint64_t));
      for (i = 0; i < node_count; i++)
	{
	  uint64_t stop = nb->edge_offsets[i + 1];
	  for (at = nb->edge_offsets[i]; at < stop; at++)
	    {
	      uint64_t o = graph_ix_at (nb->edge_targets, nb->narrow_ix, at);
	      uint64_t iat = cursor[o]++;
	      if (nb->inv_edges)
		{
		  nb->inv_edges[iat].predicate = nb->edges[at].predicate;
		  nb->inv_edges[iat].subject = nb->node_ids[i];
		}
	      graph_ix_set (nb->inv_sources, nb->narrow_ix, iat, i);
	    }
	}
    }

  /* --- 6. Publish and drop the folded-in deltas ----------------------- */
  graph->base = nb;
  nb = NULL;
  while (graph->delta_head)
    {
      graph_delta_t *prev = graph->delta_head->prev;
      graph_delta_destroy (graph->delta_head, a);
      graph->delta_head = prev;
    }
  graph->delta_tail = NULL;
  graph->delta_count = 0;
  graph->total_nodes = node_count;
  graph->total_triples = triple_count;
  if (old_base)
    graph_base_destroy (old_base, a);

  graph_free (a, cursor, (node_count + 1) * sizeof (uint64_t));
  graph_free (a, nodes, node_cap * sizeof (graph_node_id_t));
  graph_free (a, triples, triple_cap * sizeof (graph_triple_t));
  return GRAPH_OK;

fail:
  if (cursor)
    graph_free (a, cursor, (node_count + 1) * sizeof (uint64_t));
  if (nb)
    graph_base_destroy (nb, a);
  if (nodes)
    graph_free (a, nodes, node_cap * sizeof (graph_node_id_t));
  if (triples)
    graph_free (a, triples, triple_cap * sizeof (graph_triple_t));
  return err;
}

/* Degree of a single node straight out of the CSR row lengths - O(log V)
 * for the node lookup and nothing per edge.  The scalar degree BIF used to
 * run a whole-graph O(V*E) pass to read one number out of it. */
uint64_t
graph_base_node_degree (const graph_base_store_t *base, graph_node_id_t node, graph_direction_t direction)
{
  uint64_t idx, out_deg = 0, in_deg = 0;
  if (!base || !base->node_count)
    return 0;
  idx = graph_base_find_node_index (base, node);
  if (UINT64_MAX == idx)
    return 0;
  if (direction == GRAPH_DIR_OUTGOING || direction == GRAPH_DIR_BOTH)
    out_deg = base->edge_offsets[idx + 1] - base->edge_offsets[idx];
  if ((direction == GRAPH_DIR_INCOMING || direction == GRAPH_DIR_BOTH) && base->has_inverse)
    in_deg = base->inv_offsets[idx + 1] - base->inv_offsets[idx];
  return out_deg + in_deg;
}

/* ============================================================================
 * TRIPLE LOOKUP
 * ============================================================================ */

graph_triple_state_t
graph_lookup_triple (const graph_snapshot_t *snap, const graph_triple_t *triple)
{
  if (!snap || !triple)
    return GRAPH_TRIPLE_NOT_FOUND;

  graph_delta_t *delta = snap->delta_head;
  while (delta)
    {
      if (graph_delta_contains_deletion (delta, triple))
	{
	  return GRAPH_TRIPLE_DELETED;
	}
      if (graph_delta_contains_addition (delta, triple))
	{
	  return GRAPH_TRIPLE_EXISTS;
	}
      delta = delta->prev;
    }

  if (graph_base_contains (snap->graph->base, triple))
    {
      return GRAPH_TRIPLE_EXISTS;
    }

  return GRAPH_TRIPLE_NOT_FOUND;
}

/* ============================================================================
 * BULK OPERATIONS
 * ============================================================================ */

graph_error_t
graph_add_triples (graph_t *graph, const graph_triple_t *triples, uint64_t count, uint64_t *out_added)
{
  if (!graph || !triples)
    return GRAPH_ERR_NULL_PTR;

  uint64_t added = 0;
  for (uint64_t i = 0; i < count; i++)
    {
      graph_error_t err = graph_add_triple (graph, &triples[i]);
      if (err == GRAPH_OK)
	{
	  added++;
	}
    }

  if (out_added)
    *out_added = added;
  return GRAPH_OK;
}

/* ============================================================================
 * NEIGHBOR ITERATION
 * ============================================================================ */

graph_error_t
graph_iter_neighbors_init (const graph_snapshot_t *snapshot,
    graph_node_id_t node, graph_direction_t direction, const graph_pred_filter_t *pred_filter, graph_neighbor_iter_t *iter)
{
  if (!snapshot || !iter)
    return GRAPH_ERR_NULL_PTR;
  if (node == GRAPH_NODE_ID_INVALID)
    return GRAPH_ERR_INVALID_ID;

  graph_neighbor_iter_internal_t *it = (graph_neighbor_iter_internal_t *) iter;
  memset (it, 0, sizeof (*it));

  it->snapshot = snapshot;
  it->node = node;
  it->direction = direction;
  it->pred_filter = (graph_pred_filter_t *) pred_filter;
  it->status = GRAPH_ITER_OK;

  const graph_base_store_t *base = snapshot->graph->base;

  if (direction == GRAPH_DIR_OUTGOING || direction == GRAPH_DIR_BOTH)
    {
      /* The row as a slot range rather than a record pointer, because a
       * one-predicate store has no records to point at. */
      uint64_t node_ix = graph_base_node_index (base, node);
      if (UINT64_MAX != node_ix)
	{
	  it->base_row_start = base->edge_offsets[node_ix];
	  it->base_edge_count = (uint32_t) (base->edge_offsets[node_ix + 1] - it->base_row_start);
	}
    }

  it->current_delta = snapshot->delta_head;

  return GRAPH_OK;
}

static bool
pred_filter_matches (const graph_pred_filter_t *filter, graph_pred_id_t pred)
{
  if (!filter)
    return true;

  bool found = false;
  for (uint32_t i = 0; i < filter->count; i++)
    {
      if (filter->predicates[i] == pred)
	{
	  found = true;
	  break;
	}
    }

  return filter->exclude ? !found : found;
}

graph_iter_status_t
graph_iter_neighbors_next (graph_neighbor_iter_t *iter, graph_node_id_t *out_neighbor, graph_pred_id_t *out_predicate)
{
  if (!iter)
    return GRAPH_ITER_ERROR;

  graph_neighbor_iter_internal_t *it = (graph_neighbor_iter_internal_t *) iter;

  if (it->status != GRAPH_ITER_OK)
    {
      return it->status;
    }

  while (it->base_edge_idx < it->base_edge_count)
    {
      const graph_base_store_t *base = it->snapshot->graph->base;
      uint64_t at = it->base_row_start + it->base_edge_idx;
      graph_pred_id_t e_pred = graph_base_slot_pred (base, at);
      graph_node_id_t e_obj = graph_base_slot_obj (base, at);
      it->base_edge_idx++;

      if (!pred_filter_matches (it->pred_filter, e_pred))
	{
	  continue;
	}

      graph_triple_t t = {
	.subject = it->node,
	.predicate = e_pred,
	.object = e_obj
      };

      bool deleted = false;
      graph_delta_t *d = it->snapshot->delta_head;
      while (d)
	{
	  if (graph_delta_contains_deletion (d, &t))
	    {
	      deleted = true;
	      break;
	    }
	  d = d->prev;
	}

      if (!deleted)
	{
	  if (out_neighbor)
	    *out_neighbor = e_obj;
	  if (out_predicate)
	    *out_predicate = e_pred;
	  return GRAPH_ITER_OK;
	}
    }

  while (it->current_delta)
    {
      while (it->delta_add_idx < it->current_delta->addition_count)
	{
	  const graph_triple_t *t = &it->current_delta->additions[it->delta_add_idx];
	  it->delta_add_idx++;

	  if (t->subject != it->node)
	    continue;

	  if (!pred_filter_matches (it->pred_filter, t->predicate))
	    {
	      continue;
	    }

	  if (out_neighbor)
	    *out_neighbor = t->object;
	  if (out_predicate)
	    *out_predicate = t->predicate;
	  return GRAPH_ITER_OK;
	}

      it->current_delta = it->current_delta->prev;
      it->delta_add_idx = 0;
    }

  it->status = GRAPH_ITER_END;
  return GRAPH_ITER_END;
}
