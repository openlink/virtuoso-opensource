/*
 *  graph.h
 *
 *  Dynamic RDF Graph Algorithm Library
 *
 *  A pure C11 high-performance library for RDF graph storage and analytics.
 *  Designed for production systems requiring snapshot isolation, zero-allocation
 *  hot paths, and cross-platform portability.
 *
 *  Features:
 *    - RDF triple model (Subject, Predicate, Object)
 *    - Delta-based versioning with O(1) snapshots
 *    - Predicate-aware traversal indices
 *    - Snapshot-safe graph algorithms
 *    - Reusable algorithm workspaces (no hot-path allocations)
 *    - Optional GPU acceleration (Metal, runtime-dispatched)
 *
 *  Architecture Support:
 *    - x86_64: AVX2 / AVX-512 vectorization
 *    - ARM64: NEON vectorization
 *    - Scalar fallback for all platforms
 *
 *  Platform Support:
 *    - Linux (glibc, musl)
 *    - macOS (10.15+)
 *    - Windows (MSVC, MinGW)
 *
 *  Thread Safety:
 *    - Multiple readers, single writer (MRSW) for graph mutations
 *    - Snapshots are immutable and thread-safe
 *    - Algorithm workspaces are NOT thread-safe (one per thread)
 *    - No locks in traversal hot paths
 *
 *  Memory Model:
 *    - All allocations occur during initialization/commit
 *    - Hot paths (traversal, algorithms) are allocation-free
 *    - Explicit ownership: caller owns workspace, library owns graph data
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

#ifndef GRAPH_H
#define GRAPH_H

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* ============================================================================
 * VERSION
 * ============================================================================ */

#define GRAPH_VERSION_MAJOR 1
#define GRAPH_VERSION_MINOR 0
#define GRAPH_VERSION_PATCH 0
#define GRAPH_VERSION_STRING "1.0.0"

/* ============================================================================
 * COMPILER AND PLATFORM DETECTION
 * ============================================================================ */

#if defined(_MSC_VER)
#define GRAPH_MSVC 1
#define GRAPH_INLINE __forceinline
#define GRAPH_NOINLINE __declspec(noinline)
#define GRAPH_ALIGNED(n) __declspec(align(n))
#define GRAPH_THREAD_LOCAL __declspec(thread)
#elif defined(__GNUC__) || defined(__clang__)
#define GRAPH_GCC_CLANG 1
#define GRAPH_INLINE static inline __attribute__((always_inline))
#define GRAPH_NOINLINE __attribute__((noinline))
#define GRAPH_ALIGNED(n) __attribute__((aligned(n)))
#define GRAPH_THREAD_LOCAL __thread
#else
#define GRAPH_INLINE static inline
#define GRAPH_NOINLINE
#define GRAPH_ALIGNED(n)
#define GRAPH_THREAD_LOCAL
#endif

#if defined(__x86_64__) || defined(_M_X64)
#define GRAPH_ARCH_X64 1
#elif defined(__aarch64__) || defined(_M_ARM64)
#define GRAPH_ARCH_ARM64 1
#endif

#if defined(__linux__)
#define GRAPH_OS_LINUX 1
#elif defined(__APPLE__)
#define GRAPH_OS_MACOS 1
#elif defined(_WIN32)
#define GRAPH_OS_WINDOWS 1
#endif

/* ============================================================================
 * CACHE AND ALIGNMENT CONSTANTS
 * ============================================================================ */

#define GRAPH_CACHE_LINE_SIZE 64
#define GRAPH_CACHE_ALIGNED GRAPH_ALIGNED(GRAPH_CACHE_LINE_SIZE)

#define GRAPH_PAGE_SIZE 4096
#define GRAPH_PAGE_ALIGNED GRAPH_ALIGNED(GRAPH_PAGE_SIZE)

/* ============================================================================
 * ID TYPES
 * 
 * All entity identifiers are 64-bit unsigned integers.
 * Zero (0) is reserved as GRAPH_ID_INVALID for error signaling.
 * IDs are opaque handles; internal storage may differ.
 * ============================================================================ */

  typedef uint64_t graph_id_t;
  typedef uint64_t graph_node_id_t;
  typedef uint64_t graph_pred_id_t;
  typedef uint64_t graph_snap_id_t;

#define GRAPH_ID_INVALID       ((graph_id_t)0)
#define GRAPH_NODE_ID_INVALID  ((graph_node_id_t)0)
#define GRAPH_PRED_ID_INVALID  ((graph_pred_id_t)0)
#define GRAPH_SNAP_ID_INVALID  ((graph_snap_id_t)0)

#define GRAPH_ID_MAX           UINT64_MAX

/* ============================================================================
 * RDF TRIPLE MODEL
 * 
 * An RDF triple consists of:
 *   - Subject (S): The entity being described
 *   - Predicate (P): The relationship/property type
 *   - Object (O): The related entity or value
 * 
 * This library treats all components as node IDs for uniformity.
 * Literal values should be mapped to node IDs by the caller.
 * ============================================================================ */

  typedef struct graph_triple
  {
    graph_node_id_t subject;
    graph_pred_id_t predicate;
    graph_node_id_t object;
  } graph_triple_t;

/* Weighted edge for algorithms requiring edge weights */
  typedef struct graph_weighted_triple
  {
    graph_node_id_t subject;
    graph_pred_id_t predicate;
    graph_node_id_t object;
    double weight;
  } graph_weighted_triple_t;

/* ============================================================================
 * ERROR MODEL
 * 
 * All functions return graph_error_t (or use out-parameters for complex data).
 * Error codes are negative; success is GRAPH_OK (0).
 * Errors do NOT allocate; error messages are static strings.
 * ============================================================================ */

  typedef enum graph_error
  {
    /* Success */
    GRAPH_OK = 0,

    /* Parameter errors (-1 to -99) */
    GRAPH_ERR_NULL_PTR = -1,
    GRAPH_ERR_INVALID_ID = -2,
    GRAPH_ERR_INVALID_PARAM = -3,
    GRAPH_ERR_OUT_OF_RANGE = -4,
    GRAPH_ERR_DIMENSION_MISMATCH = -5,

    /* State errors (-100 to -199) */
    GRAPH_ERR_NOT_INITIALIZED = -100,
    GRAPH_ERR_ALREADY_INIT = -101,
    GRAPH_ERR_SNAPSHOT_ACTIVE = -102,
    GRAPH_ERR_NO_SNAPSHOT = -103,
    GRAPH_ERR_STALE_SNAPSHOT = -104,
    GRAPH_ERR_WRITE_LOCKED = -105,
    GRAPH_ERR_READ_LOCKED = -106,

    /* Resource errors (-200 to -299) */
    GRAPH_ERR_OUT_OF_MEMORY = -200,
    GRAPH_ERR_CAPACITY_EXCEEDED = -201,
    GRAPH_ERR_IO_ERROR = -202,
    GRAPH_ERR_MMAP_FAILED = -203,

    /* Data errors (-300 to -399) */
    GRAPH_ERR_NOT_FOUND = -300,
    /* A weight predicate was named and matched nothing, so every edge would
     * silently take the default weight of 1.0 and a weighted question would
     * be answered with unweighted numbers. */
    GRAPH_ERR_NO_WEIGHTS = -305,
    GRAPH_ERR_ALREADY_EXISTS = -301,
    GRAPH_ERR_CORRUPTED = -302,
    GRAPH_ERR_VERSION_MISMATCH = -303,
    /* The caller may not read the requested graph.  Deliberately reported
     * with the same text as GRAPH_ERR_NOT_FOUND so that the error cannot be
     * used to probe for the existence of graphs the caller cannot read. */
    GRAPH_ERR_PERMISSION_DENIED = -304,

    /* Algorithm errors (-400 to -499) */
    GRAPH_ERR_NO_PATH = -400,
    GRAPH_ERR_NEGATIVE_CYCLE = -401,
    GRAPH_ERR_NOT_CONNECTED = -402,
    GRAPH_ERR_CONVERGENCE = -403,
    GRAPH_ERR_WORKSPACE_TOO_SMALL = -404,

    /* System errors (-500 to -599) */
    GRAPH_ERR_GPU_UNAVAILABLE = -500,
    GRAPH_ERR_GPU_INIT_FAILED = -501,
    GRAPH_ERR_GPU_KERNEL_FAILED = -502,
    GRAPH_ERR_NOT_IMPLEMENTED = -503,
    GRAPH_ERR_NOT_READY = -504,

    /* Generic failure */
    GRAPH_ERR_UNKNOWN = -999
  } graph_error_t;

/**
 * Get human-readable error message for error code
 * 
 * @param err Error code
 * @return Static string describing the error (never NULL)
 */
  const char *graph_error_string (graph_error_t err);

/* ============================================================================
 * SNAPSHOT SEMANTICS
 * 
 * Snapshots provide point-in-time consistent views of the graph.
 * 
 * Key guarantees:
 *   - O(1) snapshot creation (no data copying)
 *   - Snapshots are immutable once created
 *   - Multiple snapshots can coexist
 *   - Reads from a snapshot see exactly the state at creation time
 *   - Writes to the graph do not affect existing snapshots
 * 
 * Implementation:
 *   - Delta chain: base store + ordered list of deltas
 *   - Each snapshot records the delta chain head at creation time
 *   - Reads traverse deltas in reverse order, falling back to base
 *   - Periodic compaction merges deltas into base
 * 
 * Lifecycle:
 *   1. graph_snapshot_create() - captures current state
 *   2. Use snapshot for reads/algorithms
 *   3. graph_snapshot_release() - returns resources
 * ============================================================================ */

/* Snapshot state flags */
  typedef enum graph_snap_state
  {
    GRAPH_SNAP_INVALID = 0,
    GRAPH_SNAP_ACTIVE = 1,
    GRAPH_SNAP_RELEASED = 2
  } graph_snap_state_t;

/* Snapshot metadata (opaque; use accessor functions) */
  typedef struct graph_snapshot graph_snapshot_t;

/* ============================================================================
 * MEMORY OWNERSHIP RULES
 * 
 * Clear ownership prevents memory leaks and use-after-free bugs.
 * 
 * Library-owned:
 *   - Graph internal structures (indices, storage)
 *   - Snapshot internal state
 *   - Iterator internal state
 * 
 * Caller-owned:
 *   - Algorithm workspaces (allocated by caller, sized via _workspace_size())
 *   - Result arrays passed to batch operations
 *   - Triple arrays passed to bulk insert
 * 
 * Shared ownership (reference counted):
 *   - None in this library; all ownership is explicit
 * 
 * Lifetime rules:
 *   - Workspaces must outlive algorithm execution
 *   - Snapshots must be released before graph destruction
 *   - Iterators are invalidated by mutations to the graph
 * ============================================================================ */

/* Memory allocator interface for custom allocation strategies */
  typedef struct graph_allocator
  {
    void *(*alloc) (size_t size, void *ctx);
    void *(*realloc) (void *ptr, size_t old_size, size_t new_size, void *ctx);
    void (*free) (void *ptr, size_t size, void *ctx);
    void *ctx;
  } graph_allocator_t;

/* Default allocator (uses malloc/realloc/free) */
  extern const graph_allocator_t GRAPH_DEFAULT_ALLOCATOR;

/* ============================================================================
 * THREAD-SAFETY RULES
 * 
 * The library follows the MRSW (Multiple Readers, Single Writer) model.
 * 
 * Graph mutations (write operations):
 *   - graph_add_triple(), graph_remove_triple(), graph_commit(), etc.
 *   - Require exclusive access; no concurrent reads or writes
 *   - Caller is responsible for external synchronization
 * 
 * Snapshot reads:
 *   - graph_snapshot_*(), graph_iter_*() on snapshots
 *   - Thread-safe: multiple threads can read the same snapshot
 *   - No internal locking; safe due to immutability
 * 
 * Algorithm execution:
 *   - Each thread MUST have its own workspace
 *   - Multiple threads can run algorithms on the same snapshot concurrently
 *   - The library never spawns threads; threading is caller-controlled
 * 
 * Global state:
 *   - GPU acceleration context is process-global
 *   - graph_gpu_init()/graph_gpu_shutdown() are NOT thread-safe
 * ============================================================================ */

/* Thread-safety markers for documentation */
#define GRAPH_API_THREAD_SAFE	/* Safe to call from multiple threads */
#define GRAPH_API_REQUIRES_LOCK	/* Caller must hold exclusive lock */
#define GRAPH_API_NOT_THREAD_SAFE	/* Not safe for concurrent use */

/* ============================================================================
 * EXECUTION MODES
 * 
 * Algorithms can execute in different modes based on hardware and data size.
 * Mode selection is explicit (caller chooses) or automatic (library chooses).
 * ============================================================================ */

  typedef enum graph_exec_mode
  {
    /* Automatic: library selects based on graph size and hardware */
    GRAPH_EXEC_AUTO = 0,

    /* CPU single-threaded (baseline, always available) */
    GRAPH_EXEC_CPU = 1,

    /* CPU multi-threaded (requires workspace per thread) */
    GRAPH_EXEC_CPU_MT = 2,

    /* GPU accelerated (requires GPU init, falls back to CPU on failure) */
    GRAPH_EXEC_GPU = 3
  } graph_exec_mode_t;

/* Execution context for algorithm calls */
  typedef struct graph_exec_ctx
  {
    graph_exec_mode_t mode;

    /* CPU multi-threading options */
    int num_threads;		/* 0 = auto-detect */

    /* GPU options */
    int gpu_device_id;		/* -1 = default device */

    /* Tolerances for iterative algorithms */
    double convergence_eps;	/* Default: 1e-6 */
    int max_iterations;		/* Default: 100 */
  } graph_exec_ctx_t;

/* Default execution context */
  extern const graph_exec_ctx_t GRAPH_EXEC_DEFAULT;

/* ============================================================================
 * PARALLEL EXECUTION SEAM
 *
 * The library itself never spawns threads.  The host (the Virtuoso server
 * layer) injects an executor built on its own thread machinery, and the
 * algorithm implementations use graph_parallel_begin()/run()/end() to
 * partition internal loops across workers.  Without an injected executor
 * (standalone builds, or when the host allows only one worker) every
 * section runs inline on the calling thread, so results are identical —
 * the partition only changes which worker touches which nodes.
 *
 * Determinism contract for worker callbacks:
 *   - Each worker writes only nodes/pairs in its [start,end) slice, or
 *     accumulates integer partials that the caller merges in worker order.
 *   - Floating-point reductions are performed over per-node contribution
 *     buffers in index order, never as cross-worker partial sums, so
 *     results do not depend on the worker count.
 * ============================================================================ */

/* Hard cap on workers used for one section (matches the server-side
 * [Graph] MaxThreads ceiling). */
#define GRAPH_PARALLEL_MAX_WORKERS 20

/* Minimum items per worker slice; worker counts are reduced until each
 * slice holds at least this many items. */
#define GRAPH_PARALLEL_MIN_SLICE 128

  typedef struct graph_parallel_session graph_parallel_session_t;

/* Worker callback: process items [start,end) as worker worker_index.
 * Must be self-contained — no thread-local state, no shared mutable
 * writes outside the slice. */
  typedef void (*graph_parallel_work_fn) (void *arg, uint64_t start, uint64_t end, uint32_t worker_index);

  typedef struct graph_parallel_ops
  {
    void *ctx;			/* Host context passed back to every callback */

    /* Resolved worker count for algorithm runs; must be >= 1. */
     uint32_t (*worker_count) (void *ctx);

    /* Open a parallel session, or return NULL to run everything inline.
     * max_workers caps the session; total is the largest section size. */
    graph_parallel_session_t *(*begin) (void *ctx, uint32_t max_workers, uint64_t total);

    /* Run fn over [start,end) split into n_slices contiguous slices and
     * wait for all slices to finish.  Must process every item in the
     * range exactly once: if the executor cannot run a slice itself it
     * must finish that part inline before returning, so the caller
     * never needs to retry (re-running would corrupt accumulators). */
    void (*run) (graph_parallel_session_t * session,
	uint64_t start, uint64_t end, uint32_t n_slices, graph_parallel_work_fn fn, void *arg);

    /* Close the session. */
    void (*end) (graph_parallel_session_t * session);
  } graph_parallel_ops_t;

/* Register the host executor (once, before algorithm calls).  Passing
 * NULL removes it; the library then runs everything inline. */
  void graph_parallel_set_ops (const graph_parallel_ops_t * ops);

/* Worker count the host executor allows right now (1 without one). */
  uint32_t graph_parallel_worker_count (void);

/**
 * Pin graph_parallel_worker_count() for this thread.
 *
 * Algorithms size per-worker scratch from the worker count and then slice
 * their loops by it again later.  The host's count follows a live setting
 * (enable_qp in Virtuoso), so without pinning a count that grew between
 * those two reads would index past the blocks that were allocated.  The
 * host brackets each algorithm call with these.
 */
  void graph_parallel_freeze_workers (void);
  void graph_parallel_unfreeze_workers (void);

/* Open a section driver: NULL means run inline.  max_workers caps the
 * session and is further reduced so slices keep GRAPH_PARALLEL_MIN_SLICE
 * items.  Algors call this once per algorithm run and reuse it across
 * per-iteration barriers. */
  graph_parallel_session_t *graph_parallel_begin (uint64_t total, uint32_t max_workers);

/* Execute fn over [start,end).  With a session the range is split into
 * the session's slice count and all slices run concurrently; without
 * one, fn runs inline on the calling thread. */
  void graph_parallel_run (graph_parallel_session_t * session, uint64_t start, uint64_t end, graph_parallel_work_fn fn, void *arg);

/* Close a session opened by graph_parallel_begin (NULL is allowed). */
  void graph_parallel_end (graph_parallel_session_t * session);

/* ============================================================================
 * GRAPH HANDLE (OPAQUE)
 * 
 * The graph handle is the primary interface for all operations.
 * It encapsulates:
 *   - Base triple store
 *   - Delta chain for versioning
 *   - S→(P,O) index for outgoing edge traversal
 *   - Optional O→(P,S) index for incoming edge traversal
 *   - Predicate registry for type-aware operations
 * ============================================================================ */

  typedef struct graph graph_t;

/* ============================================================================
 * GRAPH CONFIGURATION
 * ============================================================================ */

  typedef struct graph_config
  {
    /* Initial capacity hints (0 = use defaults) */
    uint64_t initial_node_capacity;
    uint64_t initial_triple_capacity;
    uint64_t initial_predicate_capacity;

    /* Index options */
    bool build_inverse_index;	/* O→(P,S) index for incoming edges */
    bool track_predicate_stats;	/* Maintain per-predicate statistics */

    /* Memory options */
    graph_allocator_t allocator;	/* Custom allocator (optional) */

    /* Storage options (Phase 4) */
    bool use_mmap;		/* Memory-map base store */
    const char *mmap_path;	/* Path for mmap file (NULL = anonymous) */
  } graph_config_t;

/* Default configuration */
  extern const graph_config_t GRAPH_CONFIG_DEFAULT;

/* ============================================================================
 * ITERATOR TYPES
 * 
 * Iterators provide efficient traversal without allocating result arrays.
 * All iterators are stack-allocatable via _iter_init() functions.
 * ============================================================================ */

/* Triple iterator state (opaque internals, stack-allocatable size) */
  typedef struct graph_triple_iter
  {
    uint8_t opaque[128];	/* Sized for internal state */
  } graph_triple_iter_t;

/* Node neighbor iterator */
  typedef struct graph_neighbor_iter
  {
    uint8_t opaque[128];
  } graph_neighbor_iter_t;

/* Iterator status */
  typedef enum graph_iter_status
  {
    GRAPH_ITER_OK = 0,		/* Current element is valid */
    GRAPH_ITER_END = 1,		/* No more elements */
    GRAPH_ITER_ERROR = -1	/* Error occurred */
  } graph_iter_status_t;

/* ============================================================================
 * ALGORITHM WORKSPACE
 * 
 * Workspaces allow algorithms to run without hot-path allocations.
 * The caller allocates the workspace buffer; the library uses it internally.
 * 
 * Usage pattern:
 *   1. size = graph_algo_*_workspace_size(graph, params);
 *   2. void *ws = malloc(size);
 *   3. graph_algo_*(graph, snapshot, params, ws, results);
 *   4. // ws can be reused for same algorithm with same/smaller graph
 *   5. free(ws);
 * ============================================================================ */

/* Workspace header (embedded at start of workspace buffer) */
  typedef struct graph_workspace_header
  {
    uint32_t magic;		/* Validation magic number */
    uint32_t algorithm_id;	/* Algorithm that owns this workspace */
    uint64_t node_capacity;	/* Max nodes this workspace supports */
    uint64_t triple_capacity;	/* Max triples this workspace supports */
  } graph_workspace_header_t;

#define GRAPH_WORKSPACE_MAGIC 0x47525753	/* "GRWS" */

/* ============================================================================
 * TRAVERSAL DIRECTION
 * ============================================================================ */

  typedef enum graph_direction
  {
    GRAPH_DIR_OUTGOING = 0,	/* S → O (follow edges forward) */
    GRAPH_DIR_INCOMING = 1,	/* O ← S (follow edges backward) */
    GRAPH_DIR_BOTH = 2		/* Undirected traversal */
  } graph_direction_t;

/* ============================================================================
 * PREDICATE FILTER
 * 
 * Many operations can be restricted to specific predicates.
 * A NULL filter means "all predicates".
 * ============================================================================ */

  typedef struct graph_pred_filter
  {
    const graph_pred_id_t *predicates;	/* Array of allowed predicates */
    uint32_t count;		/* Number of predicates in array */
    bool exclude;		/* If true, exclude these predicates */
  } graph_pred_filter_t;

/* Convenience: filter that matches all predicates */
#define GRAPH_PRED_ALL ((graph_pred_filter_t*)NULL)

/* ============================================================================
 * WEIGHT FUNCTION
 * 
 * For weighted algorithms, the caller provides a weight lookup function.
 * This allows flexible weight sources (edge properties, external data, etc.)
 * ============================================================================ */

  typedef double (*graph_weight_func_t) (graph_node_id_t subject,
      graph_pred_id_t predicate, graph_node_id_t object, void *user_data);

/* Default: all edges have weight 1.0 */
  extern const graph_weight_func_t GRAPH_WEIGHT_UNIFORM;

/* ============================================================================
 * PER-EDGE WEIGHTS, IN CSR SLOT ORDER
 *
 * A graph_weight_func_t answers "what does the edge (s,p,o) weigh", which
 * a table can only answer by searching.  A weighted traversal asks it once
 * per relaxed edge, and at one entry per edge that search is the dominant
 * cost of the whole algorithm.
 *
 * These arrays hold the same answers in the order the traversal reads
 * them: fwd[i] is the weight of the edge in forward adjacency slot i, and
 * inv[i] the weight of the one in inverse slot i -- so a relaxation is an
 * indexed load off a slot the iterator already computed.
 *
 * They are derived from a weight function, not a replacement for one.  The
 * function is still needed for edges the CSR does not hold (a snapshot
 * with pending delta additions) and for weight sources that are not
 * resolvable in advance, so a traversal handed these must still be handed
 * the function.
 * ============================================================================ */

  typedef struct graph_edge_weights
  {
    const double *fwd;		/* parallel to the forward adjacency */
    const double *inv;		/* parallel to the inverse adjacency, or NULL */
    uint64_t count;		/* edge count both were sized for */
  } graph_edge_weights_t;

/* Reports whether the weight source holds an entry for exactly (subject,
 * object), and what it is.  Distinguishing a miss from a weight that
 * happens to equal the default is what lets the resolver reproduce a
 * symmetric lookup's fallback exactly. */
  typedef bool (*graph_weight_probe_f) (void *user_data, graph_node_id_t subject, graph_node_id_t object, double *out_weight);

/* ============================================================================
 * STATISTICS AND METRICS
 * ============================================================================ */

  typedef struct graph_stats
  {
    /* Counts */
    uint64_t node_count;
    uint64_t triple_count;
    uint64_t predicate_count;

    /* Snapshot info */
    uint64_t snapshot_count;
    uint64_t delta_count;
    uint64_t delta_triple_count;

    /* Memory usage (bytes) */
    uint64_t base_store_bytes;
    uint64_t delta_bytes;
    uint64_t index_bytes;
    uint64_t total_bytes;

    /* Index statistics */
    double avg_out_degree;
    double avg_in_degree;
    uint64_t max_out_degree;
    uint64_t max_in_degree;
  } graph_stats_t;

/* ============================================================================
 * LIBRARY LIFECYCLE
 * ============================================================================ */

/**
 * Get library version string
 * 
 * @return Static version string (e.g., "1.0.0")
 */
   GRAPH_API_THREAD_SAFE const char *graph_version (void);

/**
 * Get library build information
 * 
 * @param buffer Output buffer for info string
 * @param buffer_size Size of output buffer
 * @return Number of characters written (excluding null terminator)
 */
   GRAPH_API_THREAD_SAFE int graph_build_info (char *buffer, int buffer_size);

/* ============================================================================
 * GRAPH LIFECYCLE (declared, implemented in Phase 1)
 * ============================================================================ */

/**
 * Create a new graph with the given configuration
 * 
 * @param config Configuration (NULL = use defaults)
 * @param out_graph Output pointer for created graph
 * @return GRAPH_OK on success, error code on failure
 */
   GRAPH_API_NOT_THREAD_SAFE graph_error_t graph_create (const graph_config_t * config, graph_t ** out_graph);

/**
 * Destroy a graph and release all resources
 * 
 * All snapshots must be released before calling this function.
 * 
 * @param graph Graph to destroy
 * @return GRAPH_OK on success, GRAPH_ERR_SNAPSHOT_ACTIVE if snapshots exist
 */
   GRAPH_API_NOT_THREAD_SAFE graph_error_t graph_destroy (graph_t * graph);

/**
 * Get graph statistics
 * 
 * @param graph Graph to query
 * @param out_stats Output statistics structure
 * @return GRAPH_OK on success
 */
   GRAPH_API_THREAD_SAFE graph_error_t graph_get_stats (const graph_t * graph, graph_stats_t * out_stats);

/* ============================================================================
 * SNAPSHOT LIFECYCLE (declared, implemented in Phase 1)
 * ============================================================================ */

/**
 * Create a snapshot of the current graph state
 * 
 * The snapshot captures the graph state at call time. Subsequent mutations
 * do not affect the snapshot.
 * 
 * @param graph Graph to snapshot
 * @param out_snapshot Output pointer for created snapshot
 * @return GRAPH_OK on success
 */
   GRAPH_API_REQUIRES_LOCK graph_error_t graph_snapshot_create (graph_t * graph, graph_snapshot_t ** out_snapshot);

/**
 * Retain a snapshot for a concurrent reader.  Every successful retain must
 * be paired with graph_snapshot_release().
 */
   GRAPH_API_THREAD_SAFE graph_error_t graph_snapshot_retain (graph_snapshot_t * snapshot);

/**
 * Release a snapshot
 * 
 * @param snapshot Snapshot to release
 * @return GRAPH_OK on success
 */
   GRAPH_API_THREAD_SAFE graph_error_t graph_snapshot_release (graph_snapshot_t * snapshot);

/**
 * Get the snapshot ID
 * 
 * @param snapshot Snapshot to query
 * @return Snapshot ID, or GRAPH_SNAP_ID_INVALID on error
 */
   GRAPH_API_THREAD_SAFE graph_snap_id_t graph_snapshot_get_id (const graph_snapshot_t * snapshot);

/**
 * Get node count in snapshot
 * 
 * @param snapshot Snapshot to query
 * @return Node count
 */
   GRAPH_API_THREAD_SAFE uint64_t graph_snapshot_node_count (const graph_snapshot_t * snapshot);

/**
 * Get triple count in snapshot
 * 
 * @param snapshot Snapshot to query
 * @return Triple count
 */
   GRAPH_API_THREAD_SAFE uint64_t graph_snapshot_triple_count (const graph_snapshot_t * snapshot);

/* ============================================================================
 * TRIPLE OPERATIONS (declared, implemented in Phase 1)
 * ============================================================================ */

/**
 * Add a triple to the graph
 * 
 * @param graph Graph to modify
 * @param triple Triple to add
 * @return GRAPH_OK on success
 */
   GRAPH_API_NOT_THREAD_SAFE graph_error_t graph_add_triple (graph_t * graph, const graph_triple_t * triple);

/**
 * Remove a triple from the graph
 * 
 * @param graph Graph to modify
 * @param triple Triple to remove
 * @return GRAPH_OK on success
 */
   GRAPH_API_NOT_THREAD_SAFE graph_error_t graph_remove_triple (graph_t * graph, const graph_triple_t * triple);

/**
 * Add multiple triples to the graph
 * 
 * @param graph Graph to modify
 * @param triples Array of triples to add
 * @param count Number of triples
 * @param out_added Output: number of triples successfully added (may be NULL)
 * @return GRAPH_OK on success
 */
   GRAPH_API_NOT_THREAD_SAFE
      graph_error_t graph_add_triples (graph_t * graph, const graph_triple_t * triples, uint64_t count, uint64_t * out_added);

/**
 * Commit pending mutations to create a new delta
 * 
 * @param graph Graph to commit
 * @return GRAPH_OK on success
 */
   GRAPH_API_NOT_THREAD_SAFE graph_error_t graph_commit (graph_t * graph);

/**
 * Merge the delta chain into the immutable base store (CSR + inverse CSR).
 *
 * Until this runs, every triple lives in the delta chain, where the only
 * way to find a node's neighbours is a linear scan of every addition: a
 * single node's degree costs O(E), which makes whole-graph passes O(V*E)
 * and Brandes betweenness O(V^2*E).  After it runs, neighbour lookup is a
 * binary search plus a contiguous range, so those become O(V+E) and
 * O(V*E) as documented.
 *
 * Edge order is preserved exactly: additions are already sorted by
 * (subject, predicate, object) by graph_commit(), and both the forward and
 * the inverse CSR are filled by a stable counting pass over that order.
 * Iterative algorithms therefore accumulate in the same order as before,
 * so results stay bit-identical.
 *
 * Refuses (returning GRAPH_ERR_SNAPSHOT_ACTIVE, leaving the graph usable)
 * while any snapshot is open, because snapshots pin the delta chain.
 *
 * @param graph Graph to compact
 * @return GRAPH_OK on success
 */
   GRAPH_API_NOT_THREAD_SAFE graph_error_t graph_compact (graph_t * graph);

/* ============================================================================
 * GPU ACCELERATION (declared, implemented in Phase 5)
 * ============================================================================ */

/**
 * Initialize GPU acceleration
 * 
 * This is optional; CPU execution is always available.
 * Call once at program start if GPU acceleration is desired.
 * 
 * @param device_id GPU device ID (-1 = default)
 * @return GRAPH_OK on success, GRAPH_ERR_GPU_* on failure
 */
   GRAPH_API_NOT_THREAD_SAFE graph_error_t graph_gpu_init (int device_id);

/**
 * Shutdown GPU acceleration
 */
   GRAPH_API_NOT_THREAD_SAFE void graph_gpu_shutdown (void);

/**
 * Check if GPU acceleration is available
 * 
 * @return true if GPU is initialized and available
 */
   GRAPH_API_THREAD_SAFE bool graph_gpu_available (void);

/**
 * Get GPU device information
 * 
 * @param buffer Output buffer for info string
 * @param buffer_size Size of output buffer
 * @return Number of characters written
 */
   GRAPH_API_THREAD_SAFE int graph_gpu_info (char *buffer, int buffer_size);

#ifdef __cplusplus
}
#endif

#endif				/* GRAPH_H */
