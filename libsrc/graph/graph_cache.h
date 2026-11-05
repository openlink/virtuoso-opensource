/*
 *  graph_cache.h
 *
 *  Thread-safe graph caching layer
 *
 *  Provides session-level and global graph caching to avoid repeated
 *  graph materialization from RDF_QUAD. Cache entries have TTL and
 *  are automatically evicted when memory pressure is detected.
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

#ifndef GRAPH_CACHE_H
#define GRAPH_CACHE_H

#include "graph.h"
#include "graph_internal.h"
#include <stdint.h>
#include <stdbool.h>
#include <time.h>

/* Forward declarations */
typedef struct quad_store quad_store_t;
typedef uint64_t graph_iri_id_t;

#ifdef __cplusplus
extern "C"
{
#endif

/* ============================================================================
 * CACHE CONFIGURATION
 * ============================================================================ */

#define GCACHE_MAX_ENTRIES      64	/* Maximum cached graphs */
#define GCACHE_DEFAULT_TTL_SEC  300	/* 5 minute TTL */
#define GCACHE_DEFAULT_MAX_MB   1024	/* Default cache memory budget */
/* Rounds of GCACHE_WAIT_MS a caller will wait for another thread to finish
 * a load before doing the work itself.  Bounded so that a loader that dies
 * without publishing cannot park every other caller indefinitely. */
#define GCACHE_MAX_WAITS        240	/* 240 x 250 ms = 60 s */

/* ============================================================================
 * CACHE KEY
 * ============================================================================ */

/* tx_epoch is 0 for a transaction that has not written anything, which is
 * the normal read case: those transactions all see the same committed data
 * and share one cache entry.  A transaction that HAS uncommitted writes
 * keys on its own transaction id instead, so the snapshot it builds - which
 * can see its own uncommitted rows - is never handed to anyone else.  The
 * generation stamp on the entry takes care of the other direction: after
 * any commit, entries from the previous generation are stale. */
  typedef struct gcache_key
  {
    uint64_t graph_set_id;	/* Stable hash of the sorted graph IRI set */
    graph_pred_id_t predicate_id;	/* Predicate filter (0 = all) */
    uint64_t tx_epoch;		/* 0 = shareable, else the writer's trx id */
    uint64_t hash;		/* Pre-computed hash */
  } gcache_key_t;

/* ============================================================================
 * CACHE ENTRY
 * ============================================================================ */

/* Result cache: stores pre-computed score arrays for deterministic
 * whole-graph algorithms (PageRank, eigenvector, WCC, SCC, community_id).
 * Keyed by (algorithm_id, params_hash).  Invalidated when the owning
 * snapshot entry is freed or generation-stamped stale. */
  typedef struct gcache_result
  {
    uint32_t algo_id;		/* Algorithm identifier */
    uint64_t params_hash;	/* Hash of all algorithm parameters */
    void *data;			/* Pre-computed result array */
    size_t data_size;		/* Size of data in bytes */
    bool valid;
    bool loading;		/* One caller is computing */
    /* Readers currently holding data.  gcache_result_get() hands the
     * payload out by pointer and the caller indexes it after the cache
     * mutex is released, so a slot may only be reused once every reader
     * has called gcache_result_release(). */
    uint32_t ref_count;
    uint64_t last_use;		/* Recency stamp, for LRU reuse */
  } gcache_result_t;

#define GCACHE_MAX_RESULTS 12	/* Per snapshot entry */
/* The trailing slots are reserved for results whose key includes a node
 * id - the source-keyed traversals, BFS and Dijkstra.  A traversal-heavy
 * workload produces an unbounded number of distinct keys; confining them
 * here keeps them from churning the results that are keyed only on their
 * parameters, which are the expensive ones to recompute (PageRank, WCC,
 * Louvain, Brandes).  Each range is reused least-recently-used-first
 * within itself, so neither has a cliff: the working set is what stays. */
#define GCACHE_NODE_KEYED_RESULTS 4

  typedef struct gcache_entry
  {
    gcache_key_t key;
    quad_store_t *store;	/* Cached quad store */
    graph_t *graph;		/* Graph from store */
    graph_snapshot_t *snapshot;	/* Current snapshot */

    time_t created_at;
    time_t last_access;
    time_t expires_at;

    uint64_t triple_count;
    uint64_t node_count;
    size_t memory_bytes;

    uint32_t ref_count;		/* Active references */
    uint64_t generation;	/* Generation when entry was created */
    bool valid;			/* Entry is valid */
    bool loading;		/* One caller is materializing this key */
    bool evicting;		/* Being evicted */
    bool invalidated;		/* Its graph changed while it was loading */

    gcache_result_t results[GCACHE_MAX_RESULTS];	/* Result cache */
  } gcache_entry_t;

/* ============================================================================
 * CACHE STATISTICS
 * ============================================================================ */

  typedef struct gcache_stats
  {
    uint64_t hits;
    uint64_t misses;
    uint64_t evictions;
    uint64_t result_evictions;	/* Result slots reused for a different key */
    /* Whole-graph result cache, counted separately from the snapshot
     * cache above.  A result hit is an algorithm that did not run: the
     * second node of a PageRank query, the second half of a HITS pair.
     * Without these two a reused result and a recomputed one look
     * identical from outside -- both return the right answer. */
    uint64_t result_hits;
    uint64_t result_misses;
    uint64_t loads;
    size_t current_memory;
    size_t peak_memory;
    uint32_t current_entries;
  } gcache_stats_t;

/* ============================================================================
 * CACHE HANDLE (returned to callers)
 * ============================================================================ */

  typedef struct gcache_handle
  {
    gcache_entry_t *entry;
    graph_snapshot_t *snapshot;
    bool owns_ref;
  } gcache_handle_t;

/* ============================================================================
 * CACHE OPERATIONS
 * ============================================================================ */

/* Initialize the global cache. Call once at startup. */
  graph_error_t gcache_init (void);

/* Shutdown and free all cache resources. Call at shutdown. */
  void gcache_shutdown (void);

/* Get or create cached graph. Returns handle that MUST be released. */
  graph_error_t gcache_get (uint64_t graph_id, graph_pred_id_t predicate_id, uint64_t tx_epoch, gcache_handle_t * out_handle);

/* Get an entry or reserve its key for loading.  When GRAPH_ERR_NOT_FOUND is
 * returned with *out_is_loader true, the caller is the sole loader for this
 * key and must finish with gcache_put() or gcache_abort_load().  Concurrent
 * callers wait and then reuse the installed entry. */
  graph_error_t gcache_get_or_reserve (uint64_t graph_set_id,
      graph_pred_id_t predicate_id, uint64_t tx_epoch, gcache_handle_t * out_handle, bool *out_is_loader);

  void gcache_abort_load (uint64_t graph_set_id, graph_pred_id_t predicate_id, uint64_t tx_epoch);

/* Install a fully materialized graph. The cache takes ownership of store and
 * snapshot; callers retain access through the returned handle. */
  graph_error_t gcache_put (uint64_t graph_id, graph_pred_id_t predicate_id,
      uint64_t tx_epoch, quad_store_t * store, graph_t * graph, graph_snapshot_t * snapshot, gcache_handle_t * out_handle);

/* Release cache handle. Must be called after gcache_get(). */
  void gcache_release (gcache_handle_t * handle);

/* Invalidate cache entry (call after graph modifications) */
  void gcache_invalidate (uint64_t graph_id);

/* Commit-path variant of gcache_invalidate(): takes no cache mutex and frees
 * nothing, it only records the graph; the next cache call applies it. */
  void gcache_invalidate_deferred (uint64_t graph_id);

/* Invalidate all cache entries */
  void gcache_invalidate_all (void);

/* Get cache statistics */
  void gcache_get_stats (gcache_stats_t * stats);

/* Cached graphs whose base store uses the dense index arithmetic. */
  uint32_t gcache_dense_stores (void);

/* Bytes held by the cached snapshots' node hash tables; 0 when the dense
 * path meant none were built. */
  uint64_t gcache_node_hash_bytes (void);

/* Cached graphs whose base store holds 4-byte endpoint indices. */
  uint32_t gcache_narrow_stores (void);

/* Bytes held by the cached stores' endpoint index arrays, both CSR
 * directions, at whatever width each store chose. */
  uint64_t gcache_edge_index_bytes (void);

/* Cached graphs whose base store holds no per-edge records because every
 * edge carries the same predicate. */
  uint32_t gcache_one_pred_stores (void);

/* Bytes held by the cached stores' per-edge records; 0 when every one of
 * them dropped them. */
  uint64_t gcache_edge_record_bytes (void);

/* Set cache TTL in seconds */
  void gcache_set_ttl (uint32_t ttl_seconds);

/* Set the active entry limit (clamped to the compiled maximum). */
  void gcache_set_max_entries (uint32_t max_entries);

/* Total bytes of cached snapshots allowed.  gcache_put() evicts unreferenced
 * entries, oldest first, to stay inside it, and declines to cache a snapshot
 * that still does not fit (the caller keeps and frees it). */
  void gcache_set_max_bytes (uint64_t max_bytes);

/* Tell the cache where to report whether it holds anything.
 *
 * The host keeps one cheap predicate current from this, so that a database
 * whose server has never loaded a graph does not pay to have every write
 * transaction's key set collected for a cache holding nothing.  A
 * reserved-but-still-loading entry counts as held: the loader has not read
 * a row yet, and a write committing from then on is one the finished entry
 * must not be allowed to look newer than.
 *
 * The host ORs this with cached state of its own that is keyed on the same
 * generation -- see vgraph_update_commit_gate() -- because that state can
 * outlive every entry here. */
  void gcache_set_host_live_fn (void (*fn) (int));

/* Increment the global generation counter and mark all entries from
 * older generations as evicting.  Called from the RDF_QUAD commit hook
 * so that snapshots materialised before a data modification are not
 * reused by subsequent transactions. */
  void gcache_increment_generation (void);

/* Commit-path variant: an atomic increment only.  Stale entries are refused
 * by lookups at once and freed by a later cache call, outside the commit. */
  void gcache_bump_generation (void);

/* Get the current generation counter value. */
  uint64_t gcache_get_generation (void);

/* ============================================================================
 * RESULT CACHE
 *
 * Stores pre-computed score arrays for deterministic whole-graph algorithms.
 * The caller holds a gcache_handle_t (so the snapshot entry is pinned) and
 * uses the following protocol:
 *
 *   1. gcache_result_get(handle, algo_id, params_hash, node_keyed, &out)
 *      - Returns GRAPH_OK and out->data != NULL on a cache hit.
 *      - Returns GRAPH_ERR_NOT_FOUND with out->loading == true if the
 *        caller is the sole computer; the caller must finish with
 *        gcache_result_put() or gcache_result_abort().
 *      - Returns GRAPH_ERR_NOT_FOUND with out->loading == false if
 *        another caller is computing; the caller should retry
 *        gcache_result_get() (it will wait via the load condition).
 *
 *      node_keyed says the params_hash includes a node id, which confines
 *      the entry to the reserved slots described above.  It must be the
 *      same on the get and the matching put.
 *
 *   2. gcache_result_put(handle, algo_id, params_hash, node_keyed, data, data_size)
 *      Installs the computed result.  The cache owns the data pointer
 *      and frees it with dk_free(data, data_size) on invalidation.
 *
 *   3. gcache_result_abort(handle, algo_id, params_hash)
 *      Cancels a pending computation (e.g. on error).
 *
 *   4. gcache_result_release(handle, algo_id, params_hash)
 *      Drops the reference a successful gcache_result_get() took.  Until
 *      it is called the payload pointer stays valid: the slot cannot be
 *      reused for another key.  Call it before releasing the handle that
 *      pins the entry, since the entry's own reference count is what keeps
 *      the whole result array alive.
 * ============================================================================ */

  graph_error_t gcache_result_get (gcache_handle_t * handle,
      uint32_t algo_id, uint64_t params_hash, bool node_keyed, gcache_result_t * out);
  graph_error_t gcache_result_put (gcache_handle_t * handle,
      uint32_t algo_id, uint64_t params_hash, bool node_keyed, void *data, size_t data_size);
  void gcache_result_abort (gcache_handle_t * handle, uint32_t algo_id, uint64_t params_hash);
  void gcache_result_release (gcache_handle_t * handle, uint32_t algo_id, uint64_t params_hash);

/* ============================================================================
 * CACHE KEY UTILITIES
 * ============================================================================ */

  GRAPH_INLINE uint64_t gcache_hash_key (uint64_t g, graph_pred_id_t p, uint64_t tx_epoch)
  {
    uint64_t h = (uint64_t) g;
     h ^= h >> 33;
     h *= 0xff51afd7ed558ccdULL;
     h ^= (uint64_t) p;
     h *= 0xc4ceb9fe1a85ec53ULL;
     h ^= graph_hash_u64 (tx_epoch);
     h ^= h >> 33;
     return h;
  }

  GRAPH_INLINE gcache_key_t gcache_make_key (uint64_t g, graph_pred_id_t p, uint64_t tx_epoch)
  {
    gcache_key_t k;
    k.graph_set_id = g;
    k.predicate_id = p;
    k.tx_epoch = tx_epoch;
    k.hash = gcache_hash_key (g, p, tx_epoch);
    return k;
  }

  GRAPH_INLINE bool gcache_key_equals (const gcache_key_t * a, const gcache_key_t * b)
  {
    return a->graph_set_id == b->graph_set_id && a->predicate_id == b->predicate_id && a->tx_epoch == b->tx_epoch;
  }

#ifdef __cplusplus
}
#endif

#endif /* GRAPH_CACHE_H */
