/*
 *  graph_internal.h
 *
 *  Internal structures and functions for graph library
 *
 *  This header is NOT part of the public API. It defines internal data
 *  structures, helper functions, and shared state between implementation files.
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

#ifndef GRAPH_INTERNAL_H
#define GRAPH_INTERNAL_H

#include "graph.h"
#include <string.h>

/* ============================================================================
 * PLATFORM-SPECIFIC INCLUDES
 * ============================================================================ */

/* Atomics on plain volatile int32_t counters.  The __atomic builtins need
 * gcc 4.7 or clang, not a C11 <stdatomic.h> (gcc 4.8 on CentOS 7 has none).
 * The FETCH_ forms return the value before the change. */
#ifdef GRAPH_OS_WINDOWS
#include <windows.h>
#define GRAPH_ATOMIC_FETCH_ADD(x, n) InterlockedExchangeAdd((volatile LONG*)(x), (n))
#define GRAPH_ATOMIC_FETCH_SUB(x, n) InterlockedExchangeAdd((volatile LONG*)(x), -(n))
#define GRAPH_ATOMIC_LOAD(x) InterlockedCompareExchange((volatile LONG*)(x), 0, 0)
#define GRAPH_ATOMIC_STORE(x, v) InterlockedExchange((volatile LONG*)(x), (v))
#else
#define GRAPH_ATOMIC_FETCH_ADD(x, n) __atomic_fetch_add((x), (n), __ATOMIC_SEQ_CST)
#define GRAPH_ATOMIC_FETCH_SUB(x, n) __atomic_fetch_sub((x), (n), __ATOMIC_SEQ_CST)
#define GRAPH_ATOMIC_LOAD(x) __atomic_load_n((x), __ATOMIC_SEQ_CST)
#define GRAPH_ATOMIC_STORE(x, v) __atomic_store_n((x), (v), __ATOMIC_SEQ_CST)
#endif

/* ============================================================================
 * INTERNAL CONSTANTS
 * ============================================================================ */

#define GRAPH_INITIAL_NODE_CAPACITY     (1024)
#define GRAPH_INITIAL_TRIPLE_CAPACITY   (4096)
#define GRAPH_INITIAL_PRED_CAPACITY     (64)
#define GRAPH_INITIAL_DELTA_CAPACITY    (256)

#define GRAPH_HASH_LOAD_FACTOR          (0.75)
#define GRAPH_GROWTH_FACTOR             (2)

#define GRAPH_DELTA_MAGIC               (0x44454C54)	/* "DELT" */
#define GRAPH_BASE_MAGIC                (0x42415345)	/* "BASE" */

/* ============================================================================
 * UTILITY MACROS
 * ============================================================================ */

#define GRAPH_MIN(a, b) ((a) < (b) ? (a) : (b))
#define GRAPH_MAX(a, b) ((a) > (b) ? (a) : (b))

#define GRAPH_ALIGN_UP(x, align) (((x) + (align) - 1) & ~((align) - 1))
#define GRAPH_ALIGN_DOWN(x, align) ((x) & ~((align) - 1))

#define GRAPH_IS_POWER_OF_TWO(x) ((x) && !((x) & ((x) - 1)))

/* ============================================================================
 * EDGE REPRESENTATION
 * 
 * An edge is stored as a (predicate, object) pair in adjacency lists.
 * ============================================================================ */

typedef struct graph_edge
{
  graph_pred_id_t predicate;
  graph_node_id_t object;
} graph_edge_t;

/* Inverse edge for O→(P,S) index */
typedef struct graph_inverse_edge
{
  graph_pred_id_t predicate;
  graph_node_id_t subject;
} graph_inverse_edge_t;

/* ============================================================================
 * HASH TABLE FOR NODE LOOKUP
 * 
 * Open-addressed hash table mapping node_id → slot index.
 * ============================================================================ */

typedef struct graph_node_slot
{
  graph_node_id_t node_id;	/* GRAPH_NODE_ID_INVALID = empty */
  uint32_t edge_offset;		/* Offset into edge array */
  uint32_t edge_count;		/* Number of outgoing edges */
  uint32_t inv_offset;		/* Offset into inverse edge array */
  uint32_t inv_count;		/* Number of incoming edges */
} graph_node_slot_t;

typedef struct graph_node_index
{
  graph_node_slot_t *slots;
  uint64_t slot_count;		/* Always power of 2 */
  uint64_t slot_used;		/* Number of non-empty slots */
  uint64_t slot_mask;		/* slot_count - 1, for fast modulo */
} graph_node_index_t;

/* ============================================================================
 * PREDICATE REGISTRY
 * ============================================================================ */

typedef struct graph_pred_entry
{
  graph_pred_id_t pred_id;
  uint64_t triple_count;	/* Triples with this predicate */
  uint64_t first_seen_delta;	/* Delta where first added */
} graph_pred_entry_t;

typedef struct graph_pred_registry
{
  graph_pred_entry_t *entries;
  uint64_t capacity;
  uint64_t count;
  bool track_stats;
} graph_pred_registry_t;

/* ============================================================================
 * DELTA STRUCTURE
 * 
 * A delta records additions and deletions since the previous delta.
 * Forms a singly-linked list (newest → oldest).
 * ============================================================================ */

typedef struct graph_delta
{
  uint32_t magic;		/* GRAPH_DELTA_MAGIC */
  uint64_t id;			/* Unique delta ID */
  struct graph_delta *prev;	/* Previous delta in chain */

  /* Additions */
  graph_triple_t *additions;
  uint32_t addition_count;
  uint32_t addition_capacity;

  /* Deletions */
  graph_triple_t *deletions;
  uint32_t deletion_count;
  uint32_t deletion_capacity;

  /* Reference counting for snapshot safety */
  volatile int32_t ref_count;

  /* Statistics at this delta */
  int64_t node_delta;		/* +/- nodes in this delta */
  int64_t triple_delta;		/* +/- triples in this delta */
} graph_delta_t;

/* ============================================================================
 * BASE STORE
 * 
 * Immutable, compacted storage of triples. Rebuilt during compaction.
 * ============================================================================ */

typedef struct graph_base_store
{
  uint32_t magic;		/* GRAPH_BASE_MAGIC */

  /* Node storage (sorted by node_id) */
  graph_node_id_t *node_ids;	/* Sorted unique node IDs */
  uint64_t *edge_offsets;	/* node_count + 1 offsets */
  /* Adjacency data.  NULL when one_pred: read a slot with
   * graph_base_slot_pred() / graph_base_slot_obj(), never directly. */
  graph_edge_t *edges;
  uint64_t node_count;
  uint64_t edge_count;		/* Total edges (= triple count) */

  /* Endpoint node *indices*, parallel to edges[] / inv_edges[].  Because
   * node_ids is sorted and a snapshot's node_map is the same sorted set,
   * these are directly usable as snapshot indices, which saves a hash
   * probe per edge in every traversal.
   *
   * void * because the element width is chosen when the store is built:
   * 4 bytes when narrow_ix, 8 when not.  Read them with graph_ix_at()
   * and slice them with graph_ix_slice(); nothing should index them
   * directly, and the missing type is what stops it.
   *
   * These two are the only per-edge arrays the index-only walk reads --
   * it never dereferences graph_edge_t -- so their width is the width of
   * the hot loop's memory traffic. */
  void *edge_targets;		/* index of edges[i].object */
  void *inv_sources;		/* index of inv_edges[i].subject */

  /* edge_targets / inv_sources hold 4-byte elements rather than 8.
   *
   * Sound because they hold a node *index*, bounded by node_count, not
   * an IRI_ID: a store needing 33 bits of index has more than 2^32
   * nodes, and node_ids alone would then be 34 GB before a single edge.
   * Decided from node_capacity when the store is allocated -- see
   * graph_base_create() -- and never per element.
   *
   * Not a compile-time choice, because both widths have to stay
   * reachable: GRAPH_SET_LIMIT('NarrowEdgeIndex', 0) forces the wide
   * one so the suite can run the same question down both and require
   * the same answer.  A width that could not be switched off would be
   * a width no test could compare against anything. */
  bool narrow_ix;

  /* Inverse index (optional).  inv_edges is NULL when one_pred, the same
   * way edges is; graph_base_inv_slot_pred() / _subj() read a slot. */
  uint64_t *inv_offsets;
  graph_inverse_edge_t *inv_edges;
  bool has_inverse;

  /* Every edge in this store carries the same predicate, so the
   * per-edge predicate is not stored -- and with the predicate gone
   * there is nothing left in a record: the object is
   * node_ids[edge_targets[at]] exactly, because that index was resolved
   * from that object against this same sorted table when the CSR was
   * built.  So edges[] and inv_edges[] are not allocated at all, which
   * is 32 of the 40 bytes an edge used to cost.
   *
   * A snapshot loaded under a predicate filter has one predicate by
   * construction, and the snapshot cache is keyed on the predicate, so
   * a filtered entry and an unfiltered one are separate entries that
   * cannot be served for one another.  graph_compact() does not rely on
   * that: it counts the predicates it actually sees, so an unfiltered
   * load of a graph that happens to hold one predicate gets this too.
   *
   * GRAPH_SET_LIMIT('OnePredStore', 0) keeps the records, which is the
   * only way to run the same question against both shapes. */
  bool one_pred;
  graph_pred_id_t the_pred;

  /* Which CSR this is, as a number that is never handed out twice.
   *
   * A pointer would answer the same question and answer it wrongly: a
   * store is freed when it is replaced, and the allocator may hand the
   * same address to its successor, so pointer equality can say "the same
   * CSR" about two different ones.  Anything keyed on the identity of a
   * CSR -- the per-slot weight arrays are -- has to key on this. */
  uint64_t build_id;

  /* node_ids is a contiguous run, so an id maps to its index by
   * subtraction.  Established in O(1) from the sorted table's endpoints
   * when the store is built: node_ids is sorted and deduplicated, so n
   * distinct values spanning exactly n-1 cannot have a gap between them.
   * It is a proof about this array, not a guess about the data.
   *
   * True for any loader that mints its node names before its edges,
   * because ids are handed out in first-seen order.  False for arbitrary
   * RDF, which is why it is detected rather than assumed. */
  bool dense_ids;
  graph_node_id_t dense_base;

  /* Capacities for reuse */
  uint64_t node_capacity;
  uint64_t edge_capacity;

  /* Memory ownership */
  bool is_mmap;			/* True if mmap-backed */
  void *mmap_base;		/* mmap base address */
  size_t mmap_size;		/* mmap region size */
} graph_base_store_t;

/* ============================================================================
 * SNAPSHOT STRUCTURE
 * ============================================================================ */

struct graph_snapshot
{
  graph_snap_id_t id;
  graph_t *graph;
  graph_delta_t *delta_head;	/* Delta chain head at creation */
  graph_snap_state_t state;

  /* Cached statistics at snapshot time */
  uint64_t node_count;
  uint64_t triple_count;

  /* Immutable node-id mapping built once when the snapshot is created. */
  graph_node_id_t *node_map;
  graph_node_id_t *node_hash_keys;
  uint64_t *node_hash_values;
  uint64_t node_map_count;
  uint64_t node_hash_capacity;

  /* Reference counting */
  volatile int32_t ref_count;

  /* Linked list of all snapshots (for cleanup) */
  struct graph_snapshot *next;
  struct graph_snapshot *prev;
};

/* ============================================================================
 * GRAPH STRUCTURE
 * ============================================================================ */

struct graph
{
  /* Configuration */
  graph_config_t config;
  graph_allocator_t allocator;

  /* Base store (immutable between compactions) */
  graph_base_store_t *base;

  /* Delta chain */
  graph_delta_t *delta_head;	/* Current (newest) delta */
  graph_delta_t *delta_tail;	/* Oldest delta */
  uint64_t delta_count;
  uint64_t next_delta_id;

  /* Working delta (uncommitted mutations) */
  graph_delta_t *working_delta;

  /* Node index (hash table for fast lookup) */
  graph_node_index_t node_index;

  /* Predicate registry */
  graph_pred_registry_t pred_registry;

  /* Snapshot management */
  graph_snapshot_t *snapshot_head;
  uint64_t snapshot_count;
  uint64_t next_snapshot_id;

  /* Statistics */
  uint64_t total_nodes;		/* Including delta additions */
  uint64_t total_triples;	/* Including delta additions */

  /* State flags */
  bool initialized;
  bool compacting;
};

/* ============================================================================
 * HASH FUNCTIONS
 * ============================================================================ */

GRAPH_INLINE uint64_t
graph_hash_u64 (uint64_t x)
{
  x ^= x >> 33;
  x *= 0xff51afd7ed558ccdULL;
  x ^= x >> 33;
  x *= 0xc4ceb9fe1a85ec53ULL;
  x ^= x >> 33;
  return x;
}

GRAPH_INLINE uint64_t
graph_hash_triple (graph_node_id_t s, graph_pred_id_t p, graph_node_id_t o)
{
  uint64_t h = graph_hash_u64 (s);
  h ^= graph_hash_u64 (p) + 0x9e3779b97f4a7c15ULL + (h << 6) + (h >> 2);
  h ^= graph_hash_u64 (o) + 0x9e3779b97f4a7c15ULL + (h << 6) + (h >> 2);
  return h;
}

/* ============================================================================
 * MEMORY ALLOCATION HELPERS
 * ============================================================================ */

GRAPH_INLINE void *
graph_alloc (const graph_allocator_t *a, size_t size)
{
  return a->alloc (size, a->ctx);
}

GRAPH_INLINE void *
graph_realloc (const graph_allocator_t *a, void *ptr, size_t old_size, size_t new_size)
{
  return a->realloc (ptr, old_size, new_size, a->ctx);
}

GRAPH_INLINE void
graph_free (const graph_allocator_t *a, void *ptr, size_t size)
{
  a->free (ptr, size, a->ctx);
}


/* ============================================================================
 * NODE INDEX OPERATIONS
 * ============================================================================ */

graph_error_t graph_node_index_init (graph_node_index_t * idx, const graph_allocator_t * a, uint64_t initial_capacity);

void graph_node_index_destroy (graph_node_index_t * idx, const graph_allocator_t * a);

graph_node_slot_t *graph_node_index_find (graph_node_index_t * idx, graph_node_id_t node_id);

graph_error_t graph_node_index_insert (graph_node_index_t * idx,
    const graph_allocator_t * a, graph_node_id_t node_id, graph_node_slot_t ** out_slot);

graph_error_t graph_node_index_grow (graph_node_index_t * idx, const graph_allocator_t * a);

/* ============================================================================
 * DELTA OPERATIONS
 * ============================================================================ */

graph_error_t graph_delta_create (graph_delta_t ** out_delta, const graph_allocator_t * a, uint64_t id, graph_delta_t * prev);

void graph_delta_destroy (graph_delta_t * delta, const graph_allocator_t * a);

graph_error_t graph_delta_add_triple (graph_delta_t * delta, const graph_allocator_t * a, const graph_triple_t * triple);

graph_error_t graph_delta_remove_triple (graph_delta_t * delta, const graph_allocator_t * a, const graph_triple_t * triple);

bool graph_delta_contains_addition (const graph_delta_t * delta, const graph_triple_t * triple);
bool graph_delta_contains_deletion (const graph_delta_t * delta, const graph_triple_t * triple);

void graph_delta_ref_inc (graph_delta_t * delta);
void graph_delta_ref_dec (graph_delta_t * delta, const graph_allocator_t * a);

graph_error_t graph_snapshot_build_node_map (graph_snapshot_t * snapshot);
uint64_t graph_snapshot_find_node (const graph_snapshot_t * snapshot, graph_node_id_t node_id);
uint64_t graph_snapshot_copy_node_map (const graph_snapshot_t * snapshot, graph_node_id_t * out_nodes, uint64_t capacity);

/* Approximate resident bytes of a snapshot and the store behind it, for
 * cache accounting. */
size_t graph_snapshot_memory_bytes (const graph_snapshot_t * snapshot);

/* ============================================================================
 * BASE STORE OPERATIONS
 * ============================================================================ */

/* one_pred / the_pred as described on graph_base_store_t: when one_pred is
 * true the edge records are not allocated and the_pred answers for every
 * slot.  A caller that does not know its predicate set passes false. */
graph_error_t graph_base_create (graph_base_store_t ** out_base,
    const graph_allocator_t * a,
    uint64_t node_capacity, uint64_t edge_capacity, bool build_inverse, bool one_pred, graph_pred_id_t the_pred);

void graph_base_destroy (graph_base_store_t * base, const graph_allocator_t * a);

bool graph_base_contains (const graph_base_store_t * base, const graph_triple_t * triple);

uint64_t graph_base_find_node_index (const graph_base_store_t * base, graph_node_id_t node_id);
void graph_base_set_dense_descriptor (graph_base_store_t * base);
void graph_base_set_dense_index (bool on);
bool graph_base_dense_index (void);
extern bool graph_dense_node_index;
void graph_base_set_narrow_index (bool on);
bool graph_base_narrow_index (void);
extern bool graph_narrow_edge_index;
extern uint64_t graph_base_build_seq;
void graph_base_set_one_pred_store (bool on);
bool graph_base_one_pred_store (void);
extern bool graph_one_pred_store;

/* Fill the endpoint index arrays from the adjacency arrays, for a store
 * that was loaded rather than built.  False when the store has no arrays
 * to fill. */
bool graph_base_rebuild_edge_indices (graph_base_store_t * base);

/* The build id of a store, or 0 for none.  Callers outside libgraph hold
 * only a snapshot, so this saves them reaching through it. */
uint64_t graph_snapshot_base_build_id (const graph_snapshot_t * snapshot);

/* The same rows, addressed by node index rather than by node id, and
 * yielding the parallel endpoint-index slice so a caller can address
 * algorithm state directly instead of hashing every endpoint.
 *
 * There were by-id variants of these two as well.  Nothing called them
 * once the neighbour iterator started handing an index back for every
 * edge, and a by-id form is the shape that pays a search over every node
 * id for something the caller already knows. */
graph_error_t graph_base_get_edges_at (const graph_base_store_t * base,
    uint64_t idx, uint64_t * out_start, const void **out_target_ix, uint32_t * out_count);

graph_error_t graph_base_get_inverse_edges_at (const graph_base_store_t * base,
    uint64_t idx, uint64_t * out_start, const void **out_source_ix, uint32_t * out_count);

/* Resolve one weight per CSR slot: out_fwd[i] for forward slot i and
 * out_inv[i] for inverse slot i, both sized base->edge_count.  out_inv may
 * be NULL when only the forward direction is wanted; the call fails with
 * GRAPH_ERR_NOT_FOUND if it is asked for and the store has no inverse
 * index.
 *
 * The values are what a symmetric-aware weight lookup over the same table
 * would return for the question the traversal asks in each direction, so a
 * traversal reading the arrays and one calling the lookup agree exactly.
 * Runs the two passes through graph_parallel_run(); the probe must be pure
 * (see the note on slice callbacks in graph.h). */
graph_error_t graph_base_resolve_edge_weights (const graph_base_store_t * base,
    graph_weight_probe_f probe, void *probe_user_data, bool symmetric, double default_weight, double *out_fwd, double *out_inv);

uint64_t graph_base_node_degree (const graph_base_store_t * base, graph_node_id_t node, graph_direction_t direction);

/* True when any delta in the chain records a deletion of this triple. */
bool graph_is_triple_deleted (const graph_delta_t * delta_head, const graph_triple_t * triple);

/* True when any delta in the chain records any deletion at all; lets the
 * read-only load path skip the per-edge deletion walk entirely. */
bool graph_chain_has_deletions (const graph_delta_t * delta_head);

/* ============================================================================
 * PREDICATE REGISTRY OPERATIONS
 * ============================================================================ */

graph_error_t graph_pred_registry_init (graph_pred_registry_t * reg,
    const graph_allocator_t * a, uint64_t initial_capacity, bool track_stats);

void graph_pred_registry_destroy (graph_pred_registry_t * reg, const graph_allocator_t * a);

graph_error_t graph_pred_registry_record (graph_pred_registry_t * reg,
    const graph_allocator_t * a, graph_pred_id_t pred_id, int64_t count_delta);

/* ============================================================================
 * SNAPSHOT OPERATIONS (INTERNAL)
 * ============================================================================ */

void graph_snapshot_link (graph_t * graph, graph_snapshot_t * snap);
void graph_snapshot_lib_init (void);
void graph_snapshot_unlink (graph_t * graph, graph_snapshot_t * snap);

/* ============================================================================
 * TRIPLE LOOKUP (across base + deltas)
 * ============================================================================ */

typedef enum graph_triple_state
{
  GRAPH_TRIPLE_NOT_FOUND = 0,
  GRAPH_TRIPLE_EXISTS = 1,
  GRAPH_TRIPLE_DELETED = 2
} graph_triple_state_t;

graph_triple_state_t graph_lookup_triple (const graph_snapshot_t * snap, const graph_triple_t * triple);

/* ============================================================================
 * ITERATOR INTERNALS
 * ============================================================================ */

typedef struct graph_triple_iter_internal
{
  const graph_snapshot_t *snapshot;

  /* Current position in base store */
  uint64_t base_node_idx;
  uint32_t base_edge_idx;

  /* Current position in deltas */
  graph_delta_t *current_delta;
  uint32_t delta_idx;

  /* Filter */
  graph_pred_filter_t *pred_filter;
  graph_node_id_t subject_filter;
  bool subject_filter_active;

  /* State */
  graph_iter_status_t status;
  graph_triple_t current;
} graph_triple_iter_internal_t;

typedef struct graph_neighbor_iter_internal
{
  const graph_snapshot_t *snapshot;
  graph_node_id_t node;
  graph_direction_t direction;

  /* Base store position: the row's first absolute CSR slot and how many
   * slots it has.  A slot number rather than a record pointer, because
   * a one-predicate store holds no records. */
  uint64_t base_row_start;
  uint32_t base_edge_count;
  uint32_t base_edge_idx;

  /* Delta chain traversal */
  graph_delta_t *current_delta;
  uint32_t delta_add_idx;

  /* Filter */
  graph_pred_filter_t *pred_filter;

  /* State */
  graph_iter_status_t status;
  graph_node_id_t current_neighbor;
  graph_pred_id_t current_predicate;
} graph_neighbor_iter_internal_t;

/* Static assertions for iterator size */
_Static_assert (sizeof (graph_triple_iter_internal_t) <= sizeof (graph_triple_iter_t), "graph_triple_iter_t too small");
_Static_assert (sizeof (graph_neighbor_iter_internal_t) <= sizeof (graph_neighbor_iter_t), "graph_neighbor_iter_t too small");

/* ============================================================================
 * BINARY SEARCH HELPERS
 * ============================================================================ */

GRAPH_INLINE uint64_t
graph_binary_search_u64 (const uint64_t *arr, uint64_t count, uint64_t target)
{
  uint64_t lo = 0, hi = count;
  while (lo < hi)
    {
      uint64_t mid = lo + (hi - lo) / 2;
      if (arr[mid] < target)
	{
	  lo = mid + 1;
	}
      else
	{
	  hi = mid;
	}
    }
  return lo;
}

/* Node id -> node index: the one place that choice is made.
 *
 * The subtraction is unsigned, and that is the bounds check rather than a
 * missing one.  An id below dense_base wraps to a value near UINT64_MAX
 * and fails `d < node_count`; an id above the last one fails it directly.
 * So this returns UINT64_MAX for "not in this store", which is what the
 * search path returns, and no caller can tell which path it took.
 *
 * The search path costs about 25 dependent random loads into an array of
 * every node id -- 5 MB at 633,432 nodes, so past every cache -- and the
 * CSR build does six of them per triple. */
GRAPH_INLINE uint64_t
graph_base_node_index (const graph_base_store_t *base, graph_node_id_t id)
{
  uint64_t idx;
  if (!base || !base->node_count)
    return UINT64_MAX;
  if (base->dense_ids)
    {
      uint64_t d = id - base->dense_base;
      return (d < base->node_count) ? d : UINT64_MAX;
    }
  idx = graph_binary_search_u64 ((const uint64_t *) base->node_ids, base->node_count, id);
  return (idx < base->node_count && base->node_ids[idx] == id) ? idx : UINT64_MAX;
}

/* ============================================================================
 * CSR-PARALLEL ENDPOINT INDEX SLICES
 *
 * edge_targets / inv_sources hold one node index per CSR slot at a width
 * the store chose when it was built.  These three are the only things that
 * know which width that is.
 * ============================================================================ */

#define GRAPH_IX_SIZE(narrow) ((narrow) ? sizeof (uint32_t) : sizeof (uint64_t))

/* One endpoint index out of a slice.
 *
 * The branch is on a value that is constant for the whole store, so it is
 * the same way on every iteration of every walk and predicts perfectly;
 * what it selects is the only per-edge array the index-only walk reads,
 * and at 4 bytes that array is half the memory traffic it was at 8. */
GRAPH_INLINE uint64_t
graph_ix_at (const void *slice, bool narrow, uint32_t at)
{
  return narrow ? (uint64_t) ((const uint32_t *) slice)[at] : ((const uint64_t *) slice)[at];
}

/* A slice starting at CSR slot `start`, which is what the row accessors
 * hand out: the caller's `at` then counts within one vertex's row rather
 * than across the whole array. */
GRAPH_INLINE const void *
graph_ix_slice (const void *arr, bool narrow, uint64_t start)
{
  if (!arr)
    return NULL;
  return narrow ? (const void *) ((const uint32_t *) arr + start) : (const void *) ((const uint64_t *) arr + start);
}

/* Write one endpoint index.  Only the CSR build calls this.
 *
 * A narrow slot cannot hold graph_base_node_index()'s UINT64_MAX "not in
 * this store", and does not have to: every subject and object written
 * here came out of the node set built from those same subjects and
 * objects, so the index is always present.  If that ever stopped holding,
 * the truncated 0xFFFFFFFF would be used as a row number into
 * edge_offsets and fault 34 GB past the array -- loudly, the same way the
 * wide UINT64_MAX already does. */
GRAPH_INLINE void
graph_ix_set (void *arr, bool narrow, uint64_t at, uint64_t ix)
{
  if (narrow)
    ((uint32_t *) arr)[at] = (uint32_t) ix;
  else
    ((uint64_t *) arr)[at] = ix;
}

/* ============================================================================
 * ONE CSR SLOT
 *
 * What a graph_edge_t used to be asked for, asked of the store instead.
 * On a one-predicate store there is no record: the predicate is the
 * store's, and the endpoint is node_ids[] at the index the parallel slice
 * already holds -- which is the same id the record held, because that
 * index was resolved from it against this same sorted table.
 *
 * `at` is an absolute CSR slot, not a position within a row.
 * ============================================================================ */

GRAPH_INLINE graph_pred_id_t
graph_base_slot_pred (const graph_base_store_t *b, uint64_t at)
{
  return b->one_pred ? b->the_pred : b->edges[at].predicate;
}

GRAPH_INLINE graph_node_id_t
graph_base_slot_obj (const graph_base_store_t *b, uint64_t at)
{
  return b->one_pred ? b->node_ids[graph_ix_at (b->edge_targets, b->narrow_ix, at)] : b->edges[at].object;
}

GRAPH_INLINE graph_pred_id_t
graph_base_inv_slot_pred (const graph_base_store_t *b, uint64_t at)
{
  return b->one_pred ? b->the_pred : b->inv_edges[at].predicate;
}

GRAPH_INLINE graph_node_id_t
graph_base_inv_slot_subj (const graph_base_store_t *b, uint64_t at)
{
  return b->one_pred ? b->node_ids[graph_ix_at (b->inv_sources, b->narrow_ix, at)] : b->inv_edges[at].subject;
}

GRAPH_INLINE uint64_t
graph_binary_search_edge (const graph_edge_t *edges, uint32_t count, graph_pred_id_t pred, graph_node_id_t obj)
{
  uint32_t lo = 0, hi = count;
  while (lo < hi)
    {
      uint32_t mid = lo + (hi - lo) / 2;
      if (edges[mid].predicate < pred || (edges[mid].predicate == pred && edges[mid].object < obj))
	{
	  lo = mid + 1;
	}
      else
	{
	  hi = mid;
	}
    }
  return lo;
}

/* Position of (pred, obj) within one forward CSR row, or `count` when the
 * row does not hold it.  row_start is the row's first absolute slot.
 *
 * A row is ordered by (predicate, object).  With one predicate there is no
 * predicate to compare, so the order is by object id -- and node_ids is
 * sorted, so it is by the object's *index* as well.  The search therefore
 * runs over the endpoint index slice and never reads an object id at all,
 * which is not a substitute for the record search but a cheaper one: four
 * bytes an entry against sixteen, and one integer compare against two.
 *
 * An object that is not in the store has no index, and a row cannot hold
 * an edge to it, so that answers `count` without a search. */
GRAPH_INLINE uint32_t
graph_base_row_find (const graph_base_store_t *b, uint64_t row_start, uint32_t count, graph_pred_id_t pred, graph_node_id_t obj)
{
  if (!b->one_pred)
    return (uint32_t) graph_binary_search_edge (&b->edges[row_start], count, pred, obj);
  if (pred != b->the_pred)
    return count;
  {
    uint64_t want = graph_base_node_index (b, obj);
    uint32_t lo = 0, hi = count;
    if (UINT64_MAX == want)
      return count;
    while (lo < hi)
      {
	uint32_t mid = lo + (hi - lo) / 2;
	if (graph_ix_at (b->edge_targets, b->narrow_ix, row_start + mid) < want)
	  lo = mid + 1;
	else
	  hi = mid;
      }
    return lo;
  }
}

/* True when forward slot `at` is the edge (pred, obj).  The pair that goes
 * with graph_base_row_find(), so a caller need not know which of the two
 * shapes it is looking at. */
GRAPH_INLINE bool
graph_base_slot_is (const graph_base_store_t *b, uint64_t at, graph_pred_id_t pred, graph_node_id_t obj)
{
  return graph_base_slot_pred (b, at) == pred && graph_base_slot_obj (b, at) == obj;
}

#endif /* GRAPH_INTERNAL_H */
