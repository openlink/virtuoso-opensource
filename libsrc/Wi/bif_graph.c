/*
 *  bif_graph.c
 *
 *  SQL Function Wrappers for Graph Algorithms
 *
 *  Exposes graph algorithms as SQL scalar functions callable from SPARQL.
 *
 *  Function naming convention:
 *    GRAPH_<ALGORITHM>(<subject>, [<graph>], [<predicate>], [<params>...])
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

#include "bif_graph.h"
#include "graph_quad.h"
#include "graph_algo.h"
#include "graph_algo_advanced.h"
#include "rdf_core.h"
#include "graph_internal.h"
#include "graph_cache.h"
#include "graph_neighbor.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "security.h"
#include "aqueue.h"
#include "numeric.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef _WIN32
#include <unistd.h>
#endif

/* Convert a boxed value to double, handling DV_NUMERIC, DV_DOUBLE_FLOAT,
 * DV_SINGLE_FLOAT, and integer types.  unbox_double() only handles
 * DV_DOUBLE_FLOAT; SPARQL decimal literals arrive as DV_NUMERIC. */
static double
vgraph_box_to_double (caddr_t a)
{
  if (!a)
    return 0.0;
  dtp_t dtp = DV_TYPE_OF (a);
  if (dtp == DV_DOUBLE_FLOAT)
    return unbox_double (a);
  if (dtp == DV_SINGLE_FLOAT)
    return (double) unbox_float (a);
  if (dtp == DV_SHORT_INT || dtp == DV_LONG_INT)
    return (double) unbox (a);
  if (dtp == DV_NUMERIC)
    {
      double d;
      numeric_to_double ((numeric_t) a, &d);
      return d;
    }
  return 0.0;
}


/* ============================================================================
 * WORKSPACE CACHE
 * ============================================================================ */

/* Largest algorithm workspace a single call may take.  Configurable
 * because it is what sets the per-algorithm node ceiling: an algorithm
 * whose workspace does not fit reports 42008 rather than running.  The
 * default matches the historical hard-coded 64 MB. */
#define DEFAULT_MAX_WORKSPACE_MB 64
#define VGRAPH_MIN_LIMIT_BYTES (1024 * 1024)	/* floor for MaxWorkspace and CacheMax */
#define DEFAULT_WORKSPACE_SIZE (1024 * 1024)	/* 1 MB default */

size_t vgraph_max_workspace = (size_t) DEFAULT_MAX_WORKSPACE_MB * 1024 * 1024;
static __thread void *tls_workspace = NULL;
static __thread size_t tls_workspace_size = 0;


/* [Graph] INI settings, read in viconfig.c and checked in
 * vgraph_read_config().  The initializers are the defaults. */
int32 vgraph_max_threads = 8;
int32 vgraph_min_batch = 64;
int32 vgraph_max_graph_nodes = 100000;
/* 0 = no triple limit.  Node count alone does not bound memory on a dense
 * graph, so the loader honours both.  The default matches MaxNodes at an
 * average degree of 10. */
int32 vgraph_max_graph_triples = 1000000;
int32 vgraph_cache_ttl = GCACHE_DEFAULT_TTL_SEC;
int32 vgraph_cache_max_entries = GCACHE_MAX_ENTRIES;
size_t vgraph_cache_max = (size_t) GCACHE_DEFAULT_MAX_MB * 1024 * 1024;
int32 vgraph_index_walk = 1;
int32 vgraph_dense_node_index = 1;
int32 vgraph_narrow_edge_index = 1;
int32 vgraph_one_pred_store = 1;
int32 vgraph_pagerank_gather = 1;
int32 vgraph_parallel_bfs = 1;
/* Whether a weighted traversal may resolve the weight table into one
 * weight per CSR slot before it starts.  On by default: the answers are
 * identical either way, and searching the table once per relaxed edge is
 * the dominant cost of a weighted traversal at one weight per edge.  Turn
 * it off on a memory-constrained server, or to check that the two paths
 * agree. */
int32 vgraph_edge_weight_array = 1;
/* Cap on the pair of arrays, which cost 16 bytes per edge together. */
size_t vgraph_edge_weight_max = (size_t) 2048 * 1024 * 1024;
extern int32 enable_qp;
extern long srv_cpu_count;

/* Cores this server may spread a parallel graph section over.
 *
 * Not srv_cpu_count.  That is declared `long srv_cpu_count = 4` in
 * sqlsrv.c and nothing in the tree ever assigns it -- so clamping
 * [Graph] MaxThreads against it capped every parallel graph section at four
 * workers whatever the ini said and however many cores the machine had.
 * Measured on a ten-core machine with [Graph] MaxThreads = 10 and
 * ThreadsPerQuery = 16: four workers, and raising enable_qp at run time
 * could not lift it, because the clamp happens once at boot.
 *
 * srv_cpu_count is left alone: it is server-wide, it is reported as
 * st_cpu_count, and correcting it is a change with a blast radius wider
 * than this module.  What is fixed here is this module's use of it. */
static int
vgraph_cpu_count (void)
{
#if defined(_WIN32) || defined(WIN32)
  SYSTEM_INFO si;
  GetSystemInfo (&si);
  return (int) si.dwNumberOfProcessors;
#elif defined(_SC_NPROCESSORS_ONLN)
  long n = sysconf (_SC_NPROCESSORS_ONLN);
  return (n > 0) ? (int) n : 0;
#else
  return 0;			/* unknown: do not clamp */
#endif
}

static void
vgraph_read_config (void)
{
  vgraph_edge_weight_array = vgraph_edge_weight_array ? 1 : 0;
  graph_algo_set_index_walk (vgraph_index_walk ? true : false);
  graph_base_set_dense_index (vgraph_dense_node_index ? true : false);
  graph_base_set_narrow_index (vgraph_narrow_edge_index ? true : false);
  graph_base_set_one_pred_store (vgraph_one_pred_store ? true : false);
  graph_algo_set_pagerank_gather (vgraph_pagerank_gather < 0 ? 0 : vgraph_pagerank_gather);
  graph_algo_set_parallel_bfs (vgraph_parallel_bfs ? true : false);
  if (vgraph_max_threads < 1)
    vgraph_max_threads = 1;
  if (vgraph_max_threads > 20)
    vgraph_max_threads = 20;
  {
    int cpus = vgraph_cpu_count ();
    if (cpus > 0 && vgraph_max_threads > cpus)
      vgraph_max_threads = cpus;
  }
  if (enable_qp < 2)
    vgraph_max_threads = 1;
  else if (vgraph_max_threads > enable_qp)
    vgraph_max_threads = enable_qp;
  if (vgraph_min_batch < 1)
    vgraph_min_batch = 1;
  if (vgraph_max_graph_nodes < 1)
    vgraph_max_graph_nodes = 1;
  if (vgraph_max_graph_triples < 0)
    vgraph_max_graph_triples = 0;
  if (vgraph_cache_ttl < 0)
    vgraph_cache_ttl = 0;
  if (vgraph_cache_max_entries < 0)
    vgraph_cache_max_entries = 0;
  if (vgraph_cache_max < VGRAPH_MIN_LIMIT_BYTES)
    vgraph_cache_max = VGRAPH_MIN_LIMIT_BYTES;
  if (vgraph_max_workspace < VGRAPH_MIN_LIMIT_BYTES)
    vgraph_max_workspace = VGRAPH_MIN_LIMIT_BYTES;
  gcache_set_ttl ((uint32_t) vgraph_cache_ttl);
  gcache_set_max_entries ((uint32_t) vgraph_cache_max_entries);
  gcache_set_max_bytes ((uint64_t) vgraph_cache_max);
}

/* ============================================================================
 * PARALLEL EXECUTOR FOR THE GRAPH LIBRARY SEAM
 *
 * The graph algorithms never spawn threads; they call the injected
 * graph_parallel_ops_t to fan loop sections out.  This executor is built
 * on the server's async_queue, the same machinery chash uses for parallel
 * hash fill.  Worker callbacks run with no local transaction and no query
 * context (aq_no_lt_enter), and the algorithm slice functions are pure
 * computation over snapshot and workspace pointers, so nothing in them
 * may touch qst or thread-local state.
 *
 * Session lifetime: begin allocates the async_queue, run() fans a range
 * out and blocks on aq_wait_all (no locks held across it - the caller is
 * plain algorithm code over refcount-pinned, immutable snapshots), end
 * frees the queue.  Parallel sections never nest: begin() inside a slice
 * falls back to inline execution, since a worker blocked on a nested
 * queue would deadlock the outer wait.  Cancellation surfaces as the
 * semaphore wait inside aq_wait_all being interrupted, so long-running
 * algorithm sections still land on the usual query-cancel barriers.
 * ============================================================================ */

typedef struct vgraph_par_session
{
  async_queue_t *aq;
  uint32_t n_workers;
} vgraph_par_session_t;

/* Set while a thread executes a slice (inline or as an async_queue
 * worker).  A nested graph_parallel_begin from inside a slice would
 * block an outer worker on a nested queue and deadlock the outer wait,
 * so begin() falls back to inline execution when this is set. */
static __thread int tls_in_graph_slice = 0;

static uint32_t
vgraph_par_worker_count (void *ctx)
{
  (void) ctx;
  /* vgraph_read_config already clamped this to [1,20] and srv_cpu_count.
   * enable_qp is __dbf_settable at run time, so honor the live value here
   * rather than the boot-time clamp: an admin or a test can turn query
   * parallelism off and the graph sections must follow, running inline. */
  int t = vgraph_max_threads;
  if (enable_qp < 2)
    t = 1;
  else if (t > enable_qp)
    t = enable_qp;
  return (uint32_t) t;
}

static graph_parallel_session_t *
vgraph_par_begin (void *ctx, uint32_t max_workers, uint64_t total)
{
  uint32_t wc = vgraph_par_worker_count (ctx);
  async_queue_t *aq;
  vgraph_par_session_t *ps;

  (void) total;
  if (tls_in_graph_slice)
    return NULL;		/* never nest: run the section inline */
  /* No-lock invariant at aq_wait_all: the calling thread must hold no
   * graph-layer mutex, or a worker slice acquiring the same mutex would
   * deadlock against the owner waiting in aq_wait_all.  The compile
   * mutex is the only one a BIF thread could conceivably carry in;
   * gcache and allocator locks live entirely inside their own calls.
   * (Checked in MTX_DEBUG builds; no-op otherwise.) */
  ASSERT_OUTSIDE_MTX (vgraph_scope_compile_mutex ());
  if (max_workers && max_workers < wc)
    wc = max_workers;
  if (wc < 2)
    return NULL;
  aq = aq_allocate (bootstrap_cli, (int) wc);
  if (!aq)
    return NULL;
  aq->aq_no_lt_enter = 1;
  aq->aq_do_self_if_would_wait = 1;
  ps = (vgraph_par_session_t *) dk_alloc (sizeof (vgraph_par_session_t));
  if (!ps)
    {
      dk_free_box ((caddr_t) aq);
      return NULL;
    }
  memset (ps, 0, sizeof (*ps));
  ps->aq = aq;
  ps->n_workers = wc;
  return (graph_parallel_session_t *) ps;
}

/* Slice entry, run on an async_queue worker thread.  The arguments box is
 * a plain vector of boxed ints (pointers passed as integers). */
static caddr_t
vgraph_par_slice_fn (caddr_t av, caddr_t *err_ret)
{
  caddr_t *args = (caddr_t *) av;
  graph_parallel_work_fn fn = (graph_parallel_work_fn) (ptrlong) unbox (args[0]);
  void *arg = (void *) (ptrlong) unbox (args[1]);
  uint64_t start = (uint64_t) unbox (args[2]);
  uint64_t end = (uint64_t) unbox (args[3]);
  uint32_t worker_index = (uint32_t) unbox (args[4]);

  {
    int was_in_slice = tls_in_graph_slice;
    tls_in_graph_slice = 1;
    fn (arg, start, end, worker_index);
    tls_in_graph_slice = was_in_slice;
  }
  return NULL;
}

static void
vgraph_par_run (graph_parallel_session_t *session, uint64_t start,
    uint64_t end, uint32_t n_slices, graph_parallel_work_fn fn, void *arg)
{
  vgraph_par_session_t *ps = (vgraph_par_session_t *) session;
  async_queue_t *aq = ps->aq;
  caddr_t err = NULL;
  uint64_t total = end - start;
  uint32_t k;

  if (n_slices < 1)
    n_slices = 1;
  for (k = 0; k < n_slices; k++)
    {
      uint64_t s0 = start + (total * k) / n_slices;
      uint64_t e0 = start + (total * (k + 1)) / n_slices;
      caddr_t args = dk_alloc_box (5 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      ((caddr_t *) args)[0] = box_num ((ptrlong) fn);
      ((caddr_t *) args)[1] = box_num ((ptrlong) arg);
      ((caddr_t *) args)[2] = box_num (s0);
      ((caddr_t *) args)[3] = box_num (e0);
      ((caddr_t *) args)[4] = box_num (k);
      /* Queue-only on the last request, as in chash.c: everything must
       * be queued before the caller blocks in aq_wait_all. */
      if (k == n_slices - 1)
	aq->aq_queue_only = 1;
      aq_request (aq, vgraph_par_slice_fn, args);
    }
  aq_wait_all (aq, &err);
  if (err)
    {
      /* Slice callbacks do not allocate and cannot raise except on
       * query cancellation, which unwinds the caller anyway; just log
       * and release whatever the queue captured. */
      log_error ("GRAPH parallel section error %s", ERR_MESSAGE (err));
      dk_free_tree (err);
    }
}

static void
vgraph_par_end (graph_parallel_session_t *session)
{
  vgraph_par_session_t *ps = (vgraph_par_session_t *) session;

  if (ps->aq)
    dk_free_box ((caddr_t) ps->aq);
  dk_free (ps, sizeof (*ps));
}

static const graph_parallel_ops_t vgraph_parallel_ops = {
  NULL,				/* ctx */
  vgraph_par_worker_count,
  vgraph_par_begin,
  vgraph_par_run,
  vgraph_par_end
};

size_t
vgraph_workspace_limit (void)
{
  return vgraph_max_workspace;
}

uint64_t
vgraph_max_nodes_limit (void)
{
  return (uint64_t) vgraph_max_graph_nodes;
}

uint64_t
vgraph_max_triples_limit (void)
{
  return (uint64_t) vgraph_max_graph_triples;
}

void *
vgraph_get_workspace (size_t required_size)
{
  if (required_size > vgraph_max_workspace)
    {
      return NULL;
    }

  if (tls_workspace && tls_workspace_size >= required_size)
    {
      return tls_workspace;
    }

  /* Reallocate if needed */
  if (tls_workspace)
    {
      dk_free (tls_workspace, tls_workspace_size);
    }

  size_t alloc_size = required_size > DEFAULT_WORKSPACE_SIZE ? required_size : DEFAULT_WORKSPACE_SIZE;
  tls_workspace = dk_alloc (alloc_size);
  tls_workspace_size = tls_workspace ? alloc_size : 0;

  return tls_workspace;
}

/* Bytes of workspace a thread keeps between calls.  Anything larger is
 * released: this used to keep whatever the largest call needed, up to the
 * whole 64 MB budget, for the life of the thread -- with 100 server threads
 * that is a high-water mark of gigabytes that never came back down.  A
 * megabyte covers the small graphs that dominate call counts; a big graph
 * pays one dk_alloc per call, which is nothing next to the algorithm. */
#define WORKSPACE_KEEP_SIZE (1024 * 1024)

void
vgraph_return_workspace (void *workspace)
{
  if (!workspace || workspace != tls_workspace)
    return;
  if (tls_workspace_size > WORKSPACE_KEEP_SIZE)
    {
      dk_free (tls_workspace, tls_workspace_size);
      tls_workspace = NULL;
      tls_workspace_size = 0;
    }
}

/* ============================================================================
 * RESULT BOXING
 * ============================================================================ */

void *
vgraph_box_double (double value)
{
  return box_double (value);
}

void *
vgraph_box_integer (int64_t value)
{
  return box_num (value);
}

void *
vgraph_box_double_array (const double *values, uint64_t count)
{
  caddr_t *arr = (caddr_t *) dk_alloc_box (count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  if (!arr)
    return NULL;

  for (uint64_t i = 0; i < count; i++)
    {
      arr[i] = box_double (values[i]);
    }
  return arr;
}

void *
vgraph_box_int_array (const uint64_t *values, uint64_t count)
{
  caddr_t *arr = (caddr_t *) dk_alloc_box (count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  if (!arr)
    return NULL;

  for (uint64_t i = 0; i < count; i++)
    {
      arr[i] = box_num ((long) values[i]);
    }
  return arr;
}

/* ============================================================================
 * HELPER: Load Graph Data for Algorithm
 * ============================================================================ */

/* Edge weight table for the weighted algorithms.  Declared here rather
 * than beside its builders because the whole-graph compute callbacks -
 * which come first - key the SSSP result cache on its contents. */
typedef struct weight_entry
{
  graph_node_id_t subject;
  graph_node_id_t object;
  double weight;
} weight_entry_t;

typedef struct weight_lookup
{
  weight_entry_t *entries;
  uint64_t count;
  uint64_t capacity;
  double default_weight;
  /* Set by sort_weight_lookup() once the entries are in (subject, object)
   * order.  weighted_edge_lookup() bisects when it is set and falls back
   * to a linear scan when it is not, so a builder that forgets to sort
   * is slow rather than wrong. */
  bool sorted;
  /* Identity of a table read out of a graph.  A weight table so built is
   * a function of (graph, weight predicate, cache generation), which is
   * both what lets the table itself be shared between calls and what
   * lets the SSSP result-cache key be computed without walking every
   * entry.  Zeroed for the SQL vector form, whose contents are the only
   * identity it has. */
  bool from_graph;
  graph_iri_id_t src_graph_iri;
  graph_iri_id_t src_pred_iri;
  uint64_t src_generation;
  /* Entries owned by the shared table cache rather than by this struct;
   * free_weight_lookup() drops a reference instead of freeing. */
  void *shared;
  /* Look the reverse pair up too.  An undirected graph is held one
   * direction per edge and carries one weight triple per edge, so a
   * traversal walking an edge backwards asks for (object, subject) and
   * would otherwise silently get the default weight. */
  bool symmetric;
} weight_lookup_t;

static uint64_t weight_lookup_build_id (const weight_lookup_t * wl);
static double weighted_edge_lookup (graph_node_id_t subject, graph_pred_id_t predicate, graph_node_id_t object, void *user_data);

typedef struct algo_context
{
  quad_store_t *store;
  graph_t *graph;
  graph_snapshot_t *snapshot;
  /* Obtained by vgraph_ws(), which is called only where an algorithm is
   * about to run.  NULL means "not needed yet", never "failed". */
  void *workspace;
  size_t ws_size;
  vgraph_resolved_scope_t scope;
  bool owns_store;
  gcache_handle_t cache_handle;
  bool owns_cache;
  /* A reserved-but-not-yet-published whole-graph result slot.  Every
   * caller that reserves one has to either publish or abort it, or the
   * next caller for the same (graph, algorithm, parameters) waits on a
   * computation that will never finish; cleanup_algo_context() aborts
   * whatever is still outstanding so no exit path can leak one. */
  bool result_reserved;
  uint32_t result_algo;
  uint64_t result_hash;
  bool result_node_keyed;
  /* A reference on a cached result payload.  gcache_result_get() hands
   * the payload out by pointer and the rows are mapped from it with the
   * cache mutex released, so the slot is pinned until this is dropped.
   * It lives here rather than in the batch result because every exit
   * path goes through cleanup_algo_context(), which is also what
   * releases the handle that pins the entry -- and the reference has to
   * go first. */
  bool result_ref_held;
  uint32_t result_ref_algo;
  uint64_t result_ref_hash;
  /* Source-keyed traversals (BFS, Dijkstra) compute one distance vector
   * per source and index it by target, so the source is an input to the
   * compute callback and part of the result-cache key.  The caller
   * resolves it -- the vectored path cannot read args[0] with bif_arg(),
   * which would give one row's value -- and leaves it here. */
  graph_node_id_t src_node;
  /* Weight table for the weighted traversals, owned by the caller. */
  void *weight_lookup;
  /* Direction for the weighted traversal: 0 out, 1 in, 2 both.  Part of
   * the SSSP result-cache key, so an undirected run is never served a
   * directed distance vector. */
  int weight_direction;
} algo_context_t;

static void *
vgraph_dk_alloc (size_t size, void *ctx)
{
  (void) ctx;
  return dk_alloc (size);
}

static void *
vgraph_dk_realloc (void *ptr, size_t old_size, size_t new_size, void *ctx)
{
  void *replacement;
  (void) ctx;
  replacement = dk_alloc (new_size);
  if (!replacement)
    return NULL;
  if (ptr)
    {
      memcpy (replacement, ptr, old_size < new_size ? old_size : new_size);
      dk_free (ptr, old_size);
    }
  return replacement;
}

static void
vgraph_dk_free (void *ptr, size_t size, void *ctx)
{
  (void) ctx;
  if (ptr)
    dk_free (ptr, size);
}

static const graph_allocator_t vgraph_core_allocator = {
  vgraph_dk_alloc, vgraph_dk_realloc, vgraph_dk_free, NULL
};

/* A transaction with uncommitted writes reads them, so what it loads must
 * not be shared, and nothing loaded earlier -- even by itself, before its
 * latest write -- is current for it.  Its snapshots and weight tables are
 * built privately on every call and freed with the call. */
#define VGRAPH_TXN_HAS_WRITES(qst) \
    (NULL != (qst) && NULL != ((query_instance_t *) (qst))->qi_trx && \
     lt_has_pending_changes (((query_instance_t *) (qst))->qi_trx))

/* Visibility component of the snapshot cache key.
 *
 * This used to be the transaction's write id unconditionally.  That id is
 * reassigned at every transaction boundary (lt_restart -> lt_new_w_id), so
 * in autocommit -- every SPARQL endpoint query and every isql statement --
 * each statement got a fresh key and the cache never hit: every statement
 * rebuilt the whole graph from RDF_QUAD.
 *
 * A transaction that has written nothing sees exactly the committed data,
 * as does every other read-only transaction, so they can all share one
 * entry: return 0.  The entry's generation stamp already invalidates it
 * after any commit.
 *
 * A transaction that HAS uncommitted writes can see its own rows through
 * the loader's RDF_QUAD scan, so its snapshot must not be shared.  It keys
 * on its own transaction id, which nobody else will produce. */
static uint64_t
vgraph_transaction_epoch (caddr_t *qst)
{
  if (!VGRAPH_TXN_HAS_WRITES (qst))
    return 0;
  return (uint64_t) LT_MAIN_W_ID (((query_instance_t *) qst)->qi_trx);
}


/**
 * Setup algorithm context.
 *
 * @param qst         Query state from BIF call
 * @param graph_arg   Explicit graph IRI argument (may be NULL)
 * @param pred_arg    Predicate filter argument (may be NULL)
 * @param ctx         Output context
 *
 */
static uint64_t find_node_index (const graph_snapshot_t * snapshot, graph_node_id_t node_id);
static void cleanup_algo_context (algo_context_t * ctx);
static void vgraph_batch_cache_abort (algo_context_t * ctx);
static void vgraph_batch_cache_unref (algo_context_t * ctx);
typedef struct vgraph_batch_result_s vgraph_batch_result_t;
static void vgraph_payload_release (vgraph_batch_result_t * br);
static bool vgraph_edge_weights_get (const algo_context_t * ctx,
    const weight_lookup_t * wl, graph_edge_weights_t * out, void **out_token);
static void vgraph_edge_weights_unref (void *token);
static void vgraph_edge_weights_drop (void);

/* True when a snapshot is over [Graph] MaxNodes or [Graph] MaxTriples.
 * Applied to freshly built snapshots and to cache hits alike, so lowering a
 * limit takes effect on the next call rather than only on the next load. */
static bool
vgraph_snapshot_over_limit (const graph_snapshot_t *snapshot)
{
  uint64_t max_triples;
  if (!snapshot)
    return false;
  if (snapshot->node_count > (uint64_t) vgraph_max_graph_nodes)
    return true;
  max_triples = vgraph_max_triples_limit ();
  if (max_triples && snapshot->triple_count > max_triples)
    return true;
  return false;
}

/* ============================================================================
 * TABLE-SOURCED GRAPHS
 *
 * A graph loaded from a SQL table is not in RDF_QUAD, so nothing about it
 * can be recovered from the quad store.  The cache can drop its entry at
 * any time -- a TTL expiry, memory pressure, or the generation bump any
 * RDF commit causes -- and the next algorithm call would then take the
 * miss path, scan RDF_QUAD for a graph that was never there, and return
 * an empty graph rather than an error.  That is the failure this registry
 * exists to prevent: it remembers which table a graph IRI came from, so a
 * miss reloads from the table instead.
 *
 * The plan rejected a registration mechanism, on the grounds that the
 * preload mechanism it resembles was removed for keeping a borrowed
 * pointer past the end of a statement.  That objection is about what the
 * old mechanism *stored*.  This stores an IRI id and two copied strings,
 * owns them, and never dereferences anything belonging to a caller's
 * statement -- so the defect it is named after cannot occur here.  Without
 * it the alternative is a graph that silently empties itself.
 *
 * It carries no rights of its own.  The reload runs on whichever
 * connection took the miss, so that user's own SELECT permission on the
 * table is what decides, exactly as it did for the first load.  Naming a
 * table here grants nothing.
 * ============================================================================ */

/* graph_error_string() plus " (" + up to 220 chars of SQLSTATE and message
 * + ")" -- see vgraph_load_error_set(). */
#define VGRAPH_LOAD_REASON_MAX 320

/* ============================================================================
 * TRANSIENT GRAPHS: EDGES HANDED IN BY THE CALLER
 *
 * A graph could only ever be read from RDF_QUAD or from a registered SQL
 * table.  Anything a query produced itself -- a SERVICE result, a computed
 * join, a shape that exists for one statement -- was unreachable, and
 * unreachable in the quietest possible way: IRIs intern merely by passing
 * through a result set, so the node id resolved, the node was not in the
 * loaded graph, and every score came back NULL with no error at all.
 *
 * A transient graph is the third source.  The caller hands over the edges,
 * they are kept here, and every algorithm reaches them through the same
 * IRI-addressed machinery as any other graph.  Nothing is written to the
 * quad store.
 *
 * WHY THE EDGES ARE KEPT RATHER THAN JUST THE SNAPSHOT.  A cache entry can
 * be evicted -- LRU, TTL, memory budget.  A table-sourced graph survives
 * that because the miss path re-reads the table.  A transient graph has
 * nothing to re-read unless we hold it, so an evicted one would simply
 * vanish and the next call would report "Not found", intermittently and
 * under memory pressure.  Pinning the cache entry instead would hand the
 * cache's memory budget to the caller.  So the edges are kept, at 16 bytes
 * each, bounded by [Graph] MaxTriples like any other graph, and a miss
 * reloads from them exactly as a table-sourced miss reloads from SQL.
 *
 * WHY IT IS KEYED ON THE SESSION.  A table-sourced graph can be
 * process-wide because the registry holds a *name*: every reload runs
 * SELECT on the caller's own connection, so "may this user read this"
 * is asked again each time.  A transient graph holds the rows themselves,
 * so there is no second question to ask.  Ownership is therefore the whole
 * access check, and the registration is private to the connection that
 * made it and dropped when that connection closes.  Two sessions may use
 * the same IRI and will not see each other.
 *
 * WHY THE CACHE KEY IS NOT THE IRI.  gcache is keyed on the graph id and
 * knows nothing about sessions, so if two sessions' transient graphs
 * shared an id, a cache hit would hand one session the other's data and
 * the ownership check above would never run.  Each registration therefore
 * gets a private graph id with the top bit set.  Real IRI_IDs never reach
 * 2^63 -- that is exactly why a 64-bit hash pasted into "G = #i<id>" was
 * once a "bad iri literal" -- so a private id cannot collide with one, and
 * it never reaches SQL because a transient graph is never loaded by a
 * query.
 * ========================================================================= */

#define VGRAPH_EDGE_SRC_MAX 64

typedef struct vgraph_edge_src
{
  graph_iri_id_t graph_iri;	/* the IRI the caller named; 0 when free */
  graph_iri_id_t private_id;	/* what everything downstream sees */
  graph_pred_id_t pred;
  client_connection_t *owner;	/* the only session that may see it */
  oid_t owner_uid;		/* re-checked: a pointer can be reused */
  graph_node_id_t *edges;	/* 2 ids an edge, dk_alloc'd */
  double *weights;		/* one an edge, or NULL when unweighted */
  uint64_t n_edges;
  uint64_t stamp;
} vgraph_edge_src_t;

static vgraph_edge_src_t s_edge_src[VGRAPH_EDGE_SRC_MAX];
static uint64_t s_edge_src_clock = 0;
static graph_iri_id_t s_edge_src_next_id = 1;
static dk_mutex_t *s_edge_src_mtx = NULL;
/* Occupied slots, changed under the mutex; read without it on every session
 * drop, which is every HTTP request, so those that made no graph skip it. */
static int s_edge_src_count = 0;

/* Allocated in bif_graph_init(), before any request can get here. */
static dk_mutex_t *
vgraph_edge_src_mutex (void)
{
  return s_edge_src_mtx;
}

/* The identity of a registration: the connection AND the user on it.
 *
 * The connection alone is not enough.  set_user_id() changes who a
 * connection is acting as without changing the connection, so keying on
 * the pointer alone would let one user's transient graph replace
 * another's under the same name -- and then serve it to them.  The uid is
 * also what stops a reused client_connection_t allocation from inheriting
 * the previous occupant's graphs.
 *
 * Every lookup, install and clear uses this; they disagreed once, and the
 * result was that a second user loading the same name silently destroyed
 * the first user's graph. */
static oid_t
vgraph_cli_uid (client_connection_t *cli)
{
  return (cli && cli->cli_user) ? cli->cli_user->usr_id : 0;
}

static bool
vgraph_edge_src_is (const vgraph_edge_src_t *e, graph_iri_id_t graph_iri, client_connection_t *cli)
{
  return e->graph_iri == graph_iri && e->owner == cli && e->owner_uid == vgraph_cli_uid (cli);
}

/* Caller must hold the mutex. */
static void
vgraph_edge_src_free_locked (vgraph_edge_src_t *e)
{
  if (e->edges)
    dk_free (e->edges, (size_t) e->n_edges * 2 * sizeof (graph_node_id_t));
  if (e->weights)
    dk_free (e->weights, (size_t) e->n_edges * sizeof (double));
  if (e->graph_iri)
    s_edge_src_count--;
  memset (e, 0, sizeof (*e));
}

/* The private id for (graph_iri, this session), or 0 when there is no
 * registration this caller may see. */
graph_iri_id_t
vgraph_edge_src_private_id (graph_iri_id_t graph_iri, client_connection_t *cli)
{
  dk_mutex_t *mtx = vgraph_edge_src_mutex ();
  graph_iri_id_t id = 0;
  int i;
  if (!graph_iri || !cli)
    return 0;
  if (mtx)
    mutex_enter (mtx);
  for (i = 0; i < VGRAPH_EDGE_SRC_MAX; i++)
    {
      if (vgraph_edge_src_is (&s_edge_src[i], graph_iri, cli))
	{
	  s_edge_src[i].stamp = ++s_edge_src_clock;
	  id = s_edge_src[i].private_id;
	  break;
	}
    }
  if (mtx)
    mutex_leave (mtx);
  return id;
}

/* The edges behind a private id.  Copied out under the mutex so the
 * caller can load without holding it; the copy is the loader's. */
static bool
vgraph_edge_src_get (graph_iri_id_t private_id, graph_node_id_t **out_edges,
    uint64_t *out_n, graph_pred_id_t *out_pred, double **out_weights)
{
  dk_mutex_t *mtx = vgraph_edge_src_mutex ();
  bool got = false;
  int i;
  if (out_edges)
    *out_edges = NULL;
  if (out_n)
    *out_n = 0;
  if (out_pred)
    *out_pred = GRAPH_PRED_ID_INVALID;
  if (out_weights)
    *out_weights = NULL;
  if (!VGRAPH_IS_TRANSIENT (private_id))
    return false;
  if (mtx)
    mutex_enter (mtx);
  for (i = 0; i < VGRAPH_EDGE_SRC_MAX; i++)
    {
      if (s_edge_src[i].private_id == private_id && s_edge_src[i].edges)
	{
	  size_t bytes = (size_t) s_edge_src[i].n_edges * 2 * sizeof (graph_node_id_t);
	  graph_node_id_t *copy = (graph_node_id_t *) dk_alloc (bytes);
	  if (copy)
	    {
	      memcpy (copy, s_edge_src[i].edges, bytes);
	      if (out_edges)
		*out_edges = copy;
	      if (out_n)
		*out_n = s_edge_src[i].n_edges;
	      if (out_pred)
		*out_pred = s_edge_src[i].pred;
	      if (out_weights && s_edge_src[i].weights)
		{
		  size_t wbytes = (size_t) s_edge_src[i].n_edges * sizeof (double);
		  double *wcopy = (double *) dk_alloc (wbytes);
		  if (wcopy)
		    {
		      memcpy (wcopy, s_edge_src[i].weights, wbytes);
		      *out_weights = wcopy;
		    }
		}
	      got = true;
	    }
	  break;
	}
    }
  if (mtx)
    mutex_leave (mtx);
  return got;
}

/* Install, taking ownership of `edges`.  Replaces any registration this
 * session already has under the same IRI. */
static graph_iri_id_t
vgraph_edge_src_set (graph_iri_id_t graph_iri, graph_pred_id_t pred,
    client_connection_t *cli, graph_node_id_t *edges, uint64_t n_edges, double *weights)
{
  dk_mutex_t *mtx = vgraph_edge_src_mutex ();
  int i, slot = -1, oldest = 0;
  graph_iri_id_t id = 0;
  if (!graph_iri || !cli)
    return 0;
  if (mtx)
    mutex_enter (mtx);
  for (i = 0; i < VGRAPH_EDGE_SRC_MAX; i++)
    {
      if (vgraph_edge_src_is (&s_edge_src[i], graph_iri, cli))
	{
	  slot = i;
	  break;
	}
      if (!s_edge_src[i].graph_iri && slot < 0)
	slot = i;
      if (s_edge_src[i].stamp < s_edge_src[oldest].stamp)
	oldest = i;
    }
  if (slot < 0)
    slot = oldest;
  if (s_edge_src[slot].graph_iri)
    {
      /* Evicting someone's graph, or replacing this session's own.
       * Either way the cached snapshot under the old private id must
       * go, or a later call could be served contents that are no
       * longer registered. */
      gcache_invalidate (s_edge_src[slot].private_id);
      vgraph_edge_src_free_locked (&s_edge_src[slot]);
    }
  s_edge_src[slot].graph_iri = graph_iri;
  s_edge_src_count++;
  s_edge_src[slot].private_id = VGRAPH_TRANSIENT_BIT | (s_edge_src_next_id++);
  s_edge_src[slot].pred = pred;
  s_edge_src[slot].owner = cli;
  s_edge_src[slot].owner_uid = vgraph_cli_uid (cli);
  s_edge_src[slot].edges = edges;
  s_edge_src[slot].weights = weights;
  s_edge_src[slot].n_edges = n_edges;
  s_edge_src[slot].stamp = ++s_edge_src_clock;
  id = s_edge_src[slot].private_id;
  if (mtx)
    mutex_leave (mtx);
  return id;
}

/* Forget this session's registration for `graph_iri`. */
static bool
vgraph_edge_src_clear (graph_iri_id_t graph_iri, client_connection_t *cli)
{
  dk_mutex_t *mtx = vgraph_edge_src_mutex ();
  bool had = false;
  int i;
  if (!graph_iri || !cli)
    return false;
  if (mtx)
    mutex_enter (mtx);
  for (i = 0; i < VGRAPH_EDGE_SRC_MAX; i++)
    {
      if (vgraph_edge_src_is (&s_edge_src[i], graph_iri, cli))
	{
	  gcache_invalidate (s_edge_src[i].private_id);
	  vgraph_edge_src_free_locked (&s_edge_src[i]);
	  had = true;
	  break;
	}
    }
  if (mtx)
    mutex_leave (mtx);
  return had;
}

/* Every registration this session made, when it goes away.  Installed as
 * graph_session_drop; see ltrx.h. */
void
vgraph_edge_src_drop_owner (client_connection_t *cli)
{
  dk_mutex_t *mtx = vgraph_edge_src_mutex ();
  int i;
  if (!cli || !*(volatile int *) &s_edge_src_count)
    return;
  if (mtx)
    mutex_enter (mtx);
  for (i = 0; i < VGRAPH_EDGE_SRC_MAX; i++)
    {
      if (s_edge_src[i].owner == cli && s_edge_src[i].graph_iri)
	{
	  gcache_invalidate (s_edge_src[i].private_id);
	  vgraph_edge_src_free_locked (&s_edge_src[i]);
	}
    }
  if (mtx)
    mutex_leave (mtx);
}

/* Turn the caller's boxed edge list into the compact array the registry
 * keeps.  A row is vector(s, o), or vector(s, p, o) whose middle element
 * is ignored -- the predicate is the one named at registration, because a
 * list that repeats the same predicate a million times costs a million
 * boxes to say nothing.
 *
 * Rejects rather than skips.  A malformed row used to mean a silently
 * smaller graph, which answers confidently and wrongly; the count of bad
 * rows comes back so the caller can be told which one and how many.
 *
 * Returns GRAPH_OK and sets *out_edges (dk_alloc'd, caller owns) and
 * *out_n, or an error with *out_bad set to the first bad row index. */
double vgraph_weight_box_to_double (caddr_t weight_box);
static double weight_value_to_double_ok (caddr_t weight_box, bool *ok);

static graph_error_t
vgraph_edges_from_vector (caddr_t vec, caddr_t *qst,
    graph_node_id_t **out_edges, uint64_t *out_n, int64_t *out_bad, double **out_weights, int *out_bad_what, int *out_bad_dtp)
{
  graph_node_id_t *edges;
  double *weights = NULL;
  uint64_t n, i, kept = 0;
  int tag;
  size_t bytes, wbytes = 0;

  if (out_edges)
    *out_edges = NULL;
  if (out_n)
    *out_n = 0;
  if (out_bad)
    *out_bad = -1;
  if (out_weights)
    *out_weights = NULL;
  if (out_bad_what)
    *out_bad_what = 0;
  if (out_bad_dtp)
    *out_bad_dtp = 0;
  if (!vec)
    return GRAPH_ERR_NULL_PTR;

  tag = DV_TYPE_OF (vec);
  if (DV_ARRAY_OF_POINTER != tag && DV_LIST_OF_POINTER != tag)
    return GRAPH_ERR_INVALID_PARAM;

  n = (uint64_t) BOX_ELEMENTS (vec);
  /* Checked before a byte is allocated: the limit is there to bound what
   * a caller can make the server hold, so finding out afterwards would
   * be the limit amplifying the request instead of refusing it. */
  if (vgraph_max_graph_triples && n > (uint64_t) vgraph_max_graph_triples)
    return GRAPH_ERR_CAPACITY_EXCEEDED;
  if (!n)
    {
      if (out_n)
	*out_n = 0;
      return GRAPH_OK;
    }

  bytes = (size_t) n *2 * sizeof (graph_node_id_t);
  edges = (graph_node_id_t *) dk_alloc (bytes);
  if (!edges)
    return GRAPH_ERR_OUT_OF_MEMORY;
  if (out_weights)
    {
      wbytes = (size_t) n *sizeof (double);
      weights = (double *) dk_alloc (wbytes);
      if (!weights)
	{
	  dk_free (edges, bytes);
	  return GRAPH_ERR_OUT_OF_MEMORY;
	}
    }

  for (i = 0; i < n; i++)
    {
      caddr_t row = ((caddr_t *) vec)[i];
      caddr_t *cols;
      int rtag, ncols;
      graph_node_id_t sub, obj;

      if (!row)
	{
	  if (out_bad)
	    *out_bad = (int64_t) i;
	  goto bad;
	}
      rtag = DV_TYPE_OF (row);
      if (DV_ARRAY_OF_POINTER != rtag && DV_LIST_OF_POINTER != rtag)
	{
	  if (out_bad)
	    *out_bad = (int64_t) i;
	  goto bad;
	}
      ncols = BOX_ELEMENTS (row);
      /* Weighted rows are (subject, object, weight) and unweighted ones
       * (subject, object) or (subject, predicate, object).  The third
       * element means opposite things in the two, so the mode decides
       * rather than the arity -- guessing would read a predicate as a
       * weight and answer confidently. */
      if (out_weights ? (3 != ncols) : (2 != ncols && 3 != ncols))
	{
	  if (out_bad)
	    *out_bad = (int64_t) i;
	  goto bad;
	}

      cols = (caddr_t *) row;
      sub = vgraph_node_to_id_ex (cols[0], qst);
      obj = vgraph_node_to_id_ex (out_weights ? cols[1] : cols[3 == ncols ? 2 : 1], qst);
      if (GRAPH_NODE_ID_INVALID == sub || GRAPH_NODE_ID_INVALID == obj)
	{
	  if (out_bad)
	    *out_bad = (int64_t) i;
	  if (out_bad_what)
	    *out_bad_what = (GRAPH_NODE_ID_INVALID == sub) ? 1 : 2;
	  if (out_bad_dtp)
	    *out_bad_dtp = DV_TYPE_OF (
		(GRAPH_NODE_ID_INVALID == sub) ? cols[0] : (out_weights ? cols[1] : cols[3 == ncols ? 2 : 1]));
	  goto bad;
	}

      edges[kept * 2] = sub;
      edges[kept * 2 + 1] = obj;
      if (out_weights)
	{
	  /* A NULL or non-numeric weight is a row the caller built
	   * wrong, not an edge that weighs nothing. */
	  caddr_t wbox = cols[2];
	  bool wok = false;
	  weights[kept] = weight_value_to_double_ok (wbox, &wok);
	  if (!wok)
	    {
	      if (out_bad)
		*out_bad = (int64_t) i;
	      if (out_bad_what)
		*out_bad_what = 3;
	      if (out_bad_dtp)
		*out_bad_dtp = DV_TYPE_OF (wbox);
	      goto bad;
	    }
	}
      kept++;
    }

  if (out_edges)
    *out_edges = edges;
  if (out_n)
    *out_n = kept;
  if (out_weights)
    *out_weights = weights;
  return GRAPH_OK;

bad:
  dk_free (edges, bytes);
  if (weights)
    dk_free (weights, wbytes);
  return GRAPH_ERR_INVALID_PARAM;
}

/* The compact array into a store. */
static graph_error_t
vgraph_load_from_edges (quad_store_t *store, graph_iri_id_t graph_id,
    const graph_node_id_t *edges, uint64_t n_edges, graph_pred_id_t pred, client_connection_t *cli, uint64_t *out_loaded)
{
  uint64_t i, loaded = 0;
  graph_error_t rc = GRAPH_OK;
  if (out_loaded)
    *out_loaded = 0;
  if (!store)
    return GRAPH_ERR_NULL_PTR;
  if (n_edges && !edges)
    return GRAPH_ERR_NULL_PTR;

  for (i = 0; i < n_edges; i++)
    {
      graph_quad_t quad;
      quad.graph = graph_id;
      quad.subject = edges[i * 2];
      quad.predicate = pred;
      quad.object = edges[i * 2 + 1];
      if (quad_store_add_quad (store, &quad) == GRAPH_OK)
	{
	  loaded++;
	  /* The triple count was bounded exactly before a byte was
	   * allocated, and the node count is caught on the snapshot the
	   * way GRAPH_LOAD_TABLE catches it.  What is left to watch for
	   * here is a caller who has given up: a cancelled statement
	   * must stop rather than finish building a graph nobody is
	   * waiting for. */
	  if (0 == (loaded % VGRAPH_LOAD_CHECK_ROWS) && cli && CLI_TERMINATE == cli->cli_terminate_requested)
	    {
	      rc = GRAPH_ERR_IO_ERROR;
	      goto done;
	    }
	}
    }
  quad_store_commit (store);

done:
  if (out_loaded)
    *out_loaded = loaded;
  return rc;
}

#define VGRAPH_TABLE_SRC_MAX 64

typedef struct vgraph_table_src
{
  graph_iri_id_t graph_iri;	/* 0 when the slot is free */
  char *table;
  /* The same table as the schema spells it -- qualifier.owner.name --
   * resolved once here, where the registering connection's qualifier is
   * in scope.  The commit notifier compares against this, because there
   * it only has a written key id, and a key names its table by the full
   * name and nothing else. */
  char *table_full;
  char *weight_col;		/* NULL when the source has no weights */
  /* The predicate every edge from this table is given.  Remembered
   * because a reload has to produce the same graph the first load did,
   * and because a caller asking for a different predicate must get the
   * empty graph that answer deserves rather than every edge relabelled. */
  graph_pred_id_t pred;
  uint64_t stamp;		/* for replacing the least recent */
} vgraph_table_src_t;

static vgraph_table_src_t s_table_src[VGRAPH_TABLE_SRC_MAX];
static uint64_t s_table_src_clock = 0;
static dk_mutex_t *s_table_src_mtx = NULL;
/* Set when a registered source's name could not be resolved to a table.
 * Should not happen -- the load just read the table -- but if it does, the
 * notifier cannot tell whether a write hit that source, so it stops
 * narrowing anything.  Sticky on purpose: it is cleared only by a
 * registration that does resolve. */
static int s_table_src_unresolved = 0;

static dk_mutex_t *
vgraph_table_src_mutex (void)
{
  if (!s_table_src_mtx)
    s_table_src_mtx = mutex_allocate ();
  return s_table_src_mtx;
}

/* Everything that makes the commit path worth walking, in one predicate.
 *
 * Three independent pieces of state are keyed on the graph cache's
 * generation counter, and a write has to be seen while *any* of them is
 * held:
 *
 *   the snapshot cache      reported by gcache_set_host_live_fn()
 *   the source registry     a graph can be registered against a table with
 *                           nothing cached for it yet, and a write to that
 *                           table still has to retire it
 *   the shared weight table which outlives the snapshot it was built
 *                           beside -- it is a module static here, not a
 *                           cache entry.  Leaving it out of this was a
 *                           hole: the entry expires, the gate closes, a
 *                           write to the graph is not seen, and the next
 *                           weighted call rebuilds the graph but serves
 *                           weights read before the write.  Wrong
 *                           distances, silently.
 *
 * Each piece updates its own flag and calls this; none of them may hold
 * the graph cache mutex when they do, because gcache reports into here
 * from inside it. */
static int s_gate_cache_live = 0;
static int s_gate_sources = 0;
static int s_gate_weights = 0;
/* Weight builds in progress.  Separate from s_gate_weights, which means a
 * table is published: a build that fails publishes nothing and must not
 * leave the gate up.  Changed under the weight cache mutex. */
static int s_weight_builders = 0;

static void
vgraph_update_commit_gate (void)
{
  graph_commit_notify_wanted_set ((s_gate_cache_live || s_gate_sources || s_gate_weights || s_weight_builders) ? 1 : 0);
}

/* Called by the graph cache, from inside its own mutex. */
static void
vgraph_gate_cache_live (int live)
{
  s_gate_cache_live = live;
  vgraph_update_commit_gate ();
}

/* Re-count the registry.  Call with the registry mutex held. */
static void
vgraph_table_src_publish_count_locked (void)
{
  int i;
  s_gate_sources = 0;
  for (i = 0; i < VGRAPH_TABLE_SRC_MAX; i++)
    if (s_table_src[i].graph_iri)
      {
	s_gate_sources = 1;
	break;
      }
  vgraph_update_commit_gate ();
}

/* Remember (or replace) the table a graph IRI is loaded from.  Copies the
 * strings; the caller keeps its own. */
static bool
vgraph_table_src_set (graph_iri_id_t graph_iri, const char *table, const char *weight_col, graph_pred_id_t pred)
{
  dk_mutex_t *mtx = vgraph_table_src_mutex ();
  int i, slot = -1, oldest = 0;
  if (!graph_iri || !table)
    return false;
  if (mtx)
    mutex_enter (mtx);
  for (i = 0; i < VGRAPH_TABLE_SRC_MAX; i++)
    {
      if (s_table_src[i].graph_iri == graph_iri)
	{
	  slot = i;
	  break;
	}
      if (!s_table_src[i].graph_iri && slot < 0)
	slot = i;
      if (s_table_src[i].stamp < s_table_src[oldest].stamp)
	oldest = i;
    }
  if (slot < 0)
    slot = oldest;
  if (s_table_src[slot].table)
    {
      dk_free_box (s_table_src[slot].table);
      s_table_src[slot].table = NULL;
    }
  if (s_table_src[slot].weight_col)
    {
      dk_free_box (s_table_src[slot].weight_col);
      s_table_src[slot].weight_col = NULL;
    }
  if (s_table_src[slot].table_full)
    {
      dk_free_box (s_table_src[slot].table_full);
      s_table_src[slot].table_full = NULL;
    }
  s_table_src[slot].graph_iri = graph_iri;
  s_table_src[slot].table = box_dv_short_string (table);
  {
    /* Resolved here rather than in the notifier: sch_name_to_table()
     * completes an unqualified name from the *calling thread's*
     * qualifier, and the thread that commits is not this one. */
    dbe_table_t *tb = wi_inst.wi_schema ? sch_name_to_table (wi_inst.wi_schema, (char *) table) : NULL;
    if (tb && tb->tb_name)
      {
	s_table_src[slot].table_full = box_dv_short_string (tb->tb_name);
	s_table_src_unresolved = 0;
      }
    else
      {
	s_table_src_unresolved = 1;
      }
  }
  s_table_src[slot].weight_col = (weight_col && weight_col[0]) ? box_dv_short_string (weight_col) : NULL;
  s_table_src[slot].pred = pred;
  s_table_src[slot].stamp = ++s_table_src_clock;
  vgraph_table_src_publish_count_locked ();
  if (mtx)
    mutex_leave (mtx);
  return true;
}

/* Copy out the table a graph IRI is registered against.  The caller frees
 * both boxes.  False when the graph is not table-sourced. */
static bool
vgraph_table_src_get (graph_iri_id_t graph_iri, char **out_table, char **out_weight_col, graph_pred_id_t *out_pred)
{
  dk_mutex_t *mtx = vgraph_table_src_mutex ();
  int i;
  bool found = false;
  if (out_table)
    *out_table = NULL;
  if (out_weight_col)
    *out_weight_col = NULL;
  if (out_pred)
    *out_pred = GRAPH_PRED_ID_INVALID;
  if (!graph_iri)
    return false;
  if (mtx)
    mutex_enter (mtx);
  for (i = 0; i < VGRAPH_TABLE_SRC_MAX; i++)
    {
      if (s_table_src[i].graph_iri == graph_iri && s_table_src[i].table)
	{
	  if (out_table)
	    *out_table = box_dv_short_string (s_table_src[i].table);
	  if (out_weight_col && s_table_src[i].weight_col)
	    *out_weight_col = box_dv_short_string (s_table_src[i].weight_col);
	  if (out_pred)
	    *out_pred = s_table_src[i].pred;
	  s_table_src[i].stamp = ++s_table_src_clock;
	  found = true;
	  break;
	}
    }
  if (mtx)
    mutex_leave (mtx);
  return found;
}

/* Every graph registered against one table, by the schema's own name for
 * it.  False when there are more than the caller can hold, which the
 * caller has to treat as "could be any of them".
 *
 * More than one is normal: the same table can be loaded under two graph
 * IRIs, and both of them see a write to it. */
static bool
vgraph_table_src_graphs (const char *table_full, graph_iri_id_t *out, int *n_out, int max)
{
  dk_mutex_t *mtx = vgraph_table_src_mutex ();
  int i;
  bool ok = true;
  if (!table_full)
    return false;
  if (mtx)
    mutex_enter (mtx);
  for (i = 0; i < VGRAPH_TABLE_SRC_MAX; i++)
    {
      if (!s_table_src[i].graph_iri || !s_table_src[i].table_full)
	continue;
      if (stricmp (s_table_src[i].table_full, table_full))
	continue;
      if (*n_out >= max)
	{
	  ok = false;
	  break;
	}
      out[(*n_out)++] = s_table_src[i].graph_iri;
    }
  if (mtx)
    mutex_leave (mtx);
  return ok;
}

/* Forget a graph's table.  Returns whether there was one. */
static bool
vgraph_table_src_clear (graph_iri_id_t graph_iri)
{
  dk_mutex_t *mtx = vgraph_table_src_mutex ();
  int i;
  bool found = false;
  if (mtx)
    mutex_enter (mtx);
  for (i = 0; i < VGRAPH_TABLE_SRC_MAX; i++)
    {
      if (s_table_src[i].graph_iri == graph_iri)
	{
	  if (s_table_src[i].table)
	    dk_free_box (s_table_src[i].table);
	  if (s_table_src[i].table_full)
	    dk_free_box (s_table_src[i].table_full);
	  if (s_table_src[i].weight_col)
	    dk_free_box (s_table_src[i].weight_col);
	  memset (&s_table_src[i], 0, sizeof (s_table_src[i]));
	  vgraph_table_src_publish_count_locked ();
	  found = true;
	  break;
	}
    }
  if (mtx)
    mutex_leave (mtx);
  return found;
}

/* The reason a load failed: the code's own words, plus the error the
 * internal query actually raised when there is one and the caller may see
 * it.  vgraph_load_error_get() withholds the detail from callers outside
 * the DBA group, so this collapses to the bare reason for them.
 *
 * The buffer is per thread and written only while an error is being
 * formatted; the returned pointer is used immediately by the
 * srv_make_new_error() call at the site and never stored. */
static const char *
vgraph_load_reason (graph_error_t gerr, caddr_t *qst)
{
  static __thread char reason[VGRAPH_LOAD_REASON_MAX];
  const char *detail = vgraph_load_error_get (qst);
  if (!detail[0])
    return graph_error_string (gerr);
  snprintf (reason, sizeof (reason), "%s (%s)", graph_error_string (gerr), detail);
  return reason;
}

static graph_error_t
setup_algo_context (caddr_t *qst, caddr_t graph_arg, caddr_t pred_arg, algo_context_t *ctx)
{
  bool cache_loader = false;
  bool private_load = VGRAPH_TXN_HAS_WRITES (qst);
  graph_pred_id_t cache_pred_id = GRAPH_PRED_ID_INVALID;
  uint64_t cache_tx_epoch = vgraph_transaction_epoch (qst);
  graph_iri_id_t load_graph_id;
  graph_error_t err;
  quad_store_config_t store_config = QUAD_STORE_CONFIG_DEFAULT;
  memset (ctx, 0, sizeof (*ctx));
  ctx->owns_store = true;
  /* Any detail left by an earlier load belongs to that load, not this
   * one.  Cleared before anything here can fail. */
  vgraph_load_error_clear ();
  /* Pin the parallel worker count for this call: the workspace is sized
   * from it and the loops are sliced by it, and enable_qp can change in
   * between. */
  graph_parallel_freeze_workers ();

  /* Scope resolution also runs the graph-level READ check for every graph
   * it resolves, and it runs before the cache lookup below.  A caller that
   * may not read the graph therefore never reaches gcache_get_or_reserve(),
   * so a cached snapshot can never be served to an unauthorised user and
   * the cache key does not need to carry the user id.  A revocation takes
   * effect on the next call, cached snapshot or not. */
  err = vgraph_resolve_scope (qst, graph_arg, &ctx->scope);
  if (err != GRAPH_OK)
    return err;
  load_graph_id = ctx->scope.graph_set_id;
  if (pred_arg && DV_TYPE_OF (pred_arg) != DV_DB_NULL)
    cache_pred_id = vgraph_pred_to_id_ex (pred_arg, qst);

  err = private_load ? GRAPH_ERR_NOT_FOUND
      : gcache_get_or_reserve (load_graph_id, cache_pred_id, cache_tx_epoch, &ctx->cache_handle, &cache_loader);
  if (err == GRAPH_OK)
    {
      ctx->store = ctx->cache_handle.entry->store;
      ctx->graph = ctx->cache_handle.entry->graph;
      ctx->snapshot = ctx->cache_handle.snapshot;
      ctx->owns_store = false;
      ctx->owns_cache = true;
      /* Limits apply on use, not only on load: a graph cached while the
       * limit was higher must not keep being served after an operator
       * lowers it. */
      if (vgraph_snapshot_over_limit (ctx->snapshot))
	{
	  cleanup_algo_context (ctx);
	  memset (ctx, 0, sizeof (*ctx));
	  return GRAPH_ERR_CAPACITY_EXCEEDED;
	}
      return GRAPH_OK;
    }
  if (err != GRAPH_ERR_NOT_FOUND || (!cache_loader && !private_load))
    {
      vgraph_scope_free (&ctx->scope);
      return err;
    }

  store_config.allocator = vgraph_core_allocator;
  err = quad_store_create (&store_config, &ctx->store);
  if (err != GRAPH_OK)
    goto load_failed;

  {
    graph_pred_filter_t *pf = NULL;
    graph_pred_filter_t pf_storage;
    graph_pred_id_t pred_id = cache_pred_id;

    if (pred_arg && DV_TYPE_OF (pred_arg) != DV_DB_NULL)
      {
	pred_id = vgraph_pred_to_id_ex (pred_arg, qst);
	if (pred_id != GRAPH_PRED_ID_INVALID)
	  {
	    pf_storage.predicates = &pred_id;
	    pf_storage.count = 1;
	    pf_storage.exclude = false;
	    pf = &pf_storage;
	  }
      }

    uint64_t loaded = 0;
    char *src_table = NULL, *src_wcol = NULL;

    /* A graph registered against a table is reloaded from it.  Without
     * this the miss would scan RDF_QUAD for a graph that was never
     * there and hand back an empty one -- a wrong answer rather than
     * an error, and only after the cache had dropped the entry, so it
     * would look intermittent. */
    graph_pred_id_t src_pred = GRAPH_PRED_ID_INVALID;

    /* A transient graph rebuilds from the edges the session handed in.
     * Checked before the table registry because a private id can never
     * be a table registration's key, and before RDF_QUAD because there
     * is nothing there to find. */
    graph_node_id_t *tr_edges = NULL;
    uint64_t tr_n = 0;
    graph_pred_id_t tr_pred = GRAPH_PRED_ID_INVALID;

    if (vgraph_edge_src_get (load_graph_id, &tr_edges, &tr_n, &tr_pred, NULL))
      {
	err = vgraph_load_from_edges (ctx->store, load_graph_id, tr_edges,
	    tr_n, tr_pred, ((query_instance_t *) qst)->qi_client, &loaded);
	dk_free (tr_edges, (size_t) tr_n * 2 * sizeof (graph_node_id_t));
	if (err != GRAPH_OK)
	  goto load_failed;
      }
    else if (vgraph_table_src_get (load_graph_id, &src_table, &src_wcol, &src_pred))
      {
	/* A caller naming a predicate this table was not loaded under
	 * is asking about edges the graph does not have.  Loading none
	 * is the same answer RDF would give. */
	if (GRAPH_PRED_ID_INVALID != cache_pred_id && cache_pred_id != src_pred)
	  {
	    loaded = 0;
	    err = GRAPH_OK;
	  }
	else
	  {
	    err = vgraph_load_from_table (qst, ctx->store, src_table, load_graph_id, src_pred, &loaded);
	  }
	dk_free_box (src_table);
	if (src_wcol)
	  dk_free_box (src_wcol);
	if (err != GRAPH_OK)
	  goto load_failed;
      }
    else
      {
	err = vgraph_load_from_rdf_quad (qst, ctx->store, &ctx->scope, pf, &loaded);
	if (err != GRAPH_OK)
	  goto load_failed;
      }
  }

  err = quad_store_get_graph (ctx->store, load_graph_id, false, &ctx->graph);
  if (err != GRAPH_OK || !ctx->graph)
    {
      err = GRAPH_ERR_NOT_FOUND;
      goto load_failed;
    }

  err = graph_snapshot_create (ctx->graph, &ctx->snapshot);
  if (err != GRAPH_OK)
    goto load_failed;

  /* Resource limit: refuse graphs larger than [Graph] MaxNodes
   * before the snapshot can be cached or consumed.  Callers surface
   * this as "failed to load graph: Capacity exceeded". */
  if (vgraph_snapshot_over_limit (ctx->snapshot))
    {
      graph_snapshot_release (ctx->snapshot);
      ctx->snapshot = NULL;
      err = GRAPH_ERR_CAPACITY_EXCEEDED;
      goto load_failed;
    }

  if (!private_load &&
      gcache_put (load_graph_id, cache_pred_id, cache_tx_epoch,
	  ctx->store, ctx->graph, ctx->snapshot, &ctx->cache_handle) == GRAPH_OK)
    {
      ctx->owns_store = false;
      ctx->owns_cache = true;
    }
  else if (cache_loader)
    {
      gcache_abort_load (load_graph_id, cache_pred_id, cache_tx_epoch);
    }
  return GRAPH_OK;

load_failed:
  if (ctx->snapshot)
    graph_snapshot_release (ctx->snapshot);
  if (ctx->store)
    quad_store_destroy (ctx->store);
  if (cache_loader)
    gcache_abort_load (load_graph_id, cache_pred_id, cache_tx_epoch);
  vgraph_scope_free (&ctx->scope);
  return err;
}

static void
cleanup_algo_context (algo_context_t *ctx)
{
  graph_parallel_unfreeze_workers ();
  /* Scope guard: whatever happened above, a reserved result slot is
   * never left marked "being computed", and a payload reference is never
   * left outstanding.  The reference goes before gcache_release() below:
   * the entry's own reference count is what keeps the result array
   * alive, so the order matters. */
  vgraph_batch_cache_abort (ctx);
  vgraph_batch_cache_unref (ctx);
  if (ctx->workspace)
    {
      vgraph_return_workspace (ctx->workspace);
    }
  if (ctx->owns_cache)
    {
      gcache_release (&ctx->cache_handle);
    }
  else
    {
      if (ctx->snapshot)
	graph_snapshot_release (ctx->snapshot);
      if (ctx->owns_store && ctx->store)
	quad_store_destroy (ctx->store);
    }
  vgraph_scope_free (&ctx->scope);
}

/* Vectored entry points preserve normal BIF semantics while allowing the
 * executor to invoke a graph BIF once per row batch.  Small batches retain
 * the engine fallback; larger batches share the normal cache path. */
static void
vgraph_vec_apply (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret, bif_t scalar, int node_arg_count)
{
  QNCAST (query_instance_t, qi, qst);
  int set, n_sets = qi->qi_n_sets, first_set = 0;
  db_buf_t set_mask = qi->qi_set_mask;
  graph_node_id_t *batch_ids[2] = { NULL, NULL };
  int node_arg;
  if (!ret || SSL_VEC != ret->ssl_type || n_sets < vgraph_min_batch)
    {
      *err_ret = BIF_NOT_VECTORED;
      return;
    }
  for (node_arg = 0; node_arg < node_arg_count; node_arg++)
    {
      data_col_t *node_col;
      if (SSL_VEC != args[node_arg]->ssl_type)
	{
	  *err_ret = BIF_NOT_VECTORED;
	  return;
	}
      node_col = QST_BOX (data_col_t *, qst, args[node_arg]->ssl_index);
      batch_ids[node_arg] = (graph_node_id_t *) mp_alloc_box (qi->qi_mp, n_sets * sizeof (graph_node_id_t), DV_BIN);
      if (!batch_ids[node_arg])
	{
	  *err_ret = BIF_NOT_VECTORED;
	  return;
	}
      if (vgraph_iri_to_id_batch (qst, node_col, n_sets, batch_ids[node_arg], err_ret) != GRAPH_OK)
	{
	  /* Nothing to report of our own: either the resolver set a real
	     error, or the column was not one we can read in a batch and
	     the scalar path should have it. */
	  if (!*err_ret)
	    *err_ret = BIF_NOT_VECTORED;
	  return;
	}
    }
  vgraph_batch_resolution_begin (qst, batch_ids[0], batch_ids[1], node_arg_count);
  SET_LOOP
  {
    vgraph_batch_resolution_reset ();
    caddr_t value = scalar (qst, err_ret, args);
    if (*err_ret)
      {
	vgraph_batch_resolution_end ();
	return;
      }
    qst_set (qst, ret, value);
  }
  END_SET_LOOP;
  vgraph_batch_resolution_end ();
}

/* Payload of a whole-graph batch computation.  Every whole-graph algorithm
 * builds its node_map as a plain copy of the snapshot's node map and
 * indexes its result array by that same index, which is exactly what the
 * snapshot's O(1) node hash lookup returns.  A payload therefore needs no
 * accompanying node map: each row's value is payload[hash(node_id)]. */
struct vgraph_batch_result_s
{
  const void *payload;		/* double[] or uint64_t[], per snapshot node */
  uint64_t node_count;		/* Entries in payload */
  bool is_double;		/* true: payload is double[], false: uint64_t[] */
  bool owned;			/* dk_alloc'd copy the engine must free */
  size_t size;			/* Byte size of payload (for dk_free) */
};

/* ---------------------------------------------------------------------------
 * Whole-graph result cache plumbing.
 *
 * A whole-graph payload is indexed by snapshot node index, so it can only
 * be cached alongside the snapshot it was computed from.  The snapshot
 * cache entries provide exactly that: each entry owns result slots that
 * are freed (dk_free with the recorded size) when the entry is invalidated
 * or evicted, so a cached payload never outlives the snapshot whose node
 * indices it uses.
 *
 * Slots are reused least-recently-used-first within their range once the
 * range is full, and a slot with readers is never a candidate -- every
 * caller that takes a payload out of the cache holds a reference on it
 * until cleanup_algo_context(). */

/* Try the whole-graph result cache.
 * Returns 1 on a hit: out is filled with the cache's own payload and this
 * context now holds a reference on the slot, which cleanup_algo_context()
 * drops.  The payload stays valid for as long as that reference does.
 * Returns 0 on a miss with this thread reserved as the computer — it must
 * finish with vgraph_batch_cache_publish() or, on algorithm failure, abort
 * the reserved slot.  gcache_result_get() waits internally when another
 * thread is already computing the same result.
 * Returns -1 when the result cannot be cached at all -- no snapshot cache
 * entry, or every slot in this result's range is being read by someone
 * else.  The caller then computes and hands the payload back uncached. */
static int
vgraph_batch_cache_lookup (algo_context_t *ctx, uint32_t algo_id, uint64_t params_hash, bool node_keyed, gcache_result_t *out)
{
  graph_error_t err;
  if (!ctx->owns_cache || !ctx->cache_handle.entry)
    return -1;
  err = gcache_result_get (&ctx->cache_handle, algo_id, params_hash, node_keyed, out);
  if (err == GRAPH_OK)
    {
      /* One lookup per context, so there is never a second reference to
       * displace; drop any anyway rather than leak it. */
      vgraph_batch_cache_unref (ctx);
      ctx->result_ref_held = true;
      ctx->result_ref_algo = algo_id;
      ctx->result_ref_hash = params_hash;
      return 1;
    }
  if (err != GRAPH_ERR_NOT_FOUND)
    return -1;			/* no slot reserved; compute without caching */
  ctx->result_reserved = true;
  ctx->result_algo = algo_id;
  ctx->result_hash = params_hash;
  ctx->result_node_keyed = node_keyed;
  return 0;
}

/* Install a freshly computed payload in the result cache.  Returns true
 * when the cache took ownership; false leaves the data with the caller. */
static bool
vgraph_batch_cache_publish (algo_context_t *ctx, uint32_t algo_id, uint64_t params_hash, void *data, size_t size)
{
  bool ok;
  if (!ctx->result_reserved)
    return false;
  ok = gcache_result_put (&ctx->cache_handle, algo_id, params_hash, ctx->result_node_keyed, data, size) == GRAPH_OK;
  if (!ok)
    gcache_result_abort (&ctx->cache_handle, algo_id, params_hash);
  ctx->result_reserved = false;
  return ok;
}

/* Drop the reference held on a cached payload, if any.  Safe to call when
 * none is held, so it can sit on every exit path. */
static void
vgraph_batch_cache_unref (algo_context_t *ctx)
{
  if (!ctx->result_ref_held)
    return;
  gcache_result_release (&ctx->cache_handle, ctx->result_ref_algo, ctx->result_ref_hash);
  ctx->result_ref_held = false;
}

/* Release a reservation without publishing.  Safe to call when nothing is
 * reserved, so it can sit on every failure path. */
static void
vgraph_batch_cache_abort (algo_context_t *ctx)
{
  if (!ctx->result_reserved)
    return;
  gcache_result_abort (&ctx->cache_handle, ctx->result_algo, ctx->result_hash);
  ctx->result_reserved = false;
}

/* Copy an algorithm payload into a flat dk_alloc'd buffer for the result
 * cache.  Returns NULL on allocation failure. */
static void *
vgraph_batch_flat_copy (const void *src, uint64_t count, size_t *size_out)
{
  size_t size;
  void *copy;
  if (!src || count > (((uint64_t) 1) << 40))
    return NULL;
  size = (size_t) count *sizeof (uint64_t);
  copy = dk_alloc (size);
  if (!copy)
    return NULL;
  memcpy (copy, src, size);
  *size_out = size;
  return copy;
}

/* Parameter hashes for the result cache key (algo_id distinguishes the
 * algorithms, the hash distinguishes their parameter sets). */
static uint64_t
vgraph_params_hash_double (uint64_t h, double v)
{
  uint64_t bits;
  memcpy (&bits, &v, sizeof (bits));
  h ^= graph_hash_u64 (bits);
  h *= 0x9e3779b97f4a7c15ULL;
  return h;
}

static uint64_t
vgraph_params_hash_int (uint64_t h, int64_t v)
{
  h ^= graph_hash_u64 ((uint64_t) v);
  h *= 0x9e3779b97f4a7c15ULL;
  return h;
}

/* The workspace, obtained on first use rather than before the call.
 *
 * It used to be allocated by the dispatcher, before the compute callback
 * had consulted the whole-graph result cache -- and on a source-keyed
 * sweep every row but the first is a cache hit, so the algorithm never
 * runs and the workspace is never written to.  At 633,432 vertices
 * Dijkstra's workspace is about 15 MB, over the megabyte a thread keeps
 * between calls, so each of those rows did a dk_alloc and a dk_free of 15
 * MB for nothing -- and freeing a block that size hands it back to the
 * kernel, which is one madvise(2) per row.
 *
 * Measured on 34,185,747 edges: a single-source weighted sweep over all
 * 633,432 vertices took 76 s, and a stack sample through it put 99.5% of
 * the server's time in free_large -> madvise underneath ins_call_bif.
 * The same sweep is about 1.5 s once the allocation only happens when the
 * algorithm actually runs.
 *
 * Returns NULL when the size is over [Graph] MaxWorkspace; the callers
 * turn that into GRAPH_ERR_OUT_OF_MEMORY, and ctx->workspace staying NULL
 * is what lets the BIFs tell that case from any other out-of-memory and
 * name the limit. */
static void *
vgraph_ws (algo_context_t *ctx)
{
  if (ctx->workspace)
    return ctx->workspace;
  ctx->workspace = vgraph_get_workspace (ctx->ws_size);
  return ctx->workspace;
}

/* Compute callback for a whole-graph algorithm.  Each callback parses its
 * own optional arguments (setting *err_ret itself on invalid values),
 * runs the algorithm fresh or reuses the whole-graph result cache, and
 * fills out.  out->owned is true only for dk_alloc'd payloads, which the
 * engine frees (dk_free(payload, size)) after the rows are mapped. */
typedef graph_error_t (*vgraph_whole_graph_compute_fn) (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args,
    algo_context_t * ctx, vgraph_batch_result_t * out);

typedef struct
{
  vgraph_whole_graph_compute_fn compute;
  size_t (*workspace_size) (const graph_snapshot_t * snap);
  /* Which argument carries the node a row maps on.  0 for the per-node
   * algorithms, whose first argument is the node.  1 for the
   * source-keyed traversals, where args[0] is the fixed source and
   * args[1] the target that varies per row.  The graph and predicate
   * arguments follow the row argument, so they are at
   * row_arg_index + 1 and + 2. */
  int row_arg_index;
  /* Which array of the payload a row reads.  0 for a single-array
   * result, which is every algorithm but HITS.  HITS computes hub and
   * authority in one pass and caches them as one two-array payload, so
   * its two predicates share a compute callback and differ only here:
   * hub reads the first half, authority the second.  Asking for both in
   * one query therefore runs the power iteration once. */
  int payload_half;
  /* Read the payload as reachability rather than as its own value: 1
   * where the entry is finite, 0 where it is not.  Depth-first search
   * is breadth-first search read this way -- whether a node was reached
   * does not depend on the order it was reached in -- so the two share
   * one traversal and one cache entry instead of running two. */
  int as_reach;
} vgraph_whole_graph_algo_t;

/* Fill a batch result from a whole-graph result cache hit.  Both payload
 * element types are 8 bytes wide, so the cached size maps to entries
 * uniformly. */
static void
vgraph_batch_fill_cached (const gcache_result_t *res, bool is_double, vgraph_batch_result_t *out)
{
  out->payload = res->data;
  out->node_count = res->data_size / sizeof (uint64_t);
  out->is_double = is_double;
  out->owned = false;
  out->size = res->data_size;
}

/* Two 8-byte arrays of node_count entries each, laid end to end: the
 * distance vector a row maps on, followed by the parent vector the
 * path-returning forms need.  node_count covers the first array only, so
 * row mapping and vgraph_payload_* index it exactly as they index a
 * single-array payload; vgraph_payload_parents() reaches the second. */
static void
vgraph_batch_fill_cached_pair (const gcache_result_t *res, bool is_double, vgraph_batch_result_t *out)
{
  out->payload = res->data;
  out->node_count = res->data_size / (2 * sizeof (uint64_t));
  out->is_double = is_double;
  out->owned = false;
  out->size = res->data_size;
}

/* Shared tail of the whole-graph compute callbacks: fill out from a
 * freshly computed payload and, when the result cache is available,
 * install a flat dk_alloc'd copy of it there.  On publish failure (or
 * copy allocation failure) the payload stays valid for row mapping: a
 * copy is left engine-owned, a workspace-backed array is used directly. */
static void
vgraph_batch_finish_double (algo_context_t *ctx, uint32_t algo_id,
    uint64_t params_hash, const double *scores, uint64_t node_count, vgraph_batch_result_t *out)
{
  size_t copy_size = 0;
  out->is_double = true;
  out->node_count = node_count;
  out->payload = NULL;
  out->owned = false;
  out->size = 0;
  if (!scores || !node_count)
    {
      vgraph_batch_cache_abort (ctx);
      return;
    }
  double *copy = (double *) vgraph_batch_flat_copy (scores, node_count, &copy_size);
  if (copy)
    {
      out->payload = copy;
      out->size = copy_size;
      out->owned = !vgraph_batch_cache_publish (ctx, algo_id, params_hash, copy, copy_size);
      return;
    }
  vgraph_batch_cache_abort (ctx);
  out->payload = scores;	/* workspace-backed, valid until cleanup */
}

static void
vgraph_batch_finish_int (algo_context_t *ctx, uint32_t algo_id,
    uint64_t params_hash, const uint64_t *values, uint64_t node_count, vgraph_batch_result_t *out)
{
  size_t copy_size = 0;
  out->is_double = false;
  out->node_count = node_count;
  out->payload = NULL;
  out->owned = false;
  out->size = 0;
  if (!values || !node_count)
    {
      vgraph_batch_cache_abort (ctx);
      return;
    }
  uint64_t *copy = (uint64_t *) vgraph_batch_flat_copy (values, node_count, &copy_size);
  if (copy)
    {
      out->payload = copy;
      out->size = copy_size;
      out->owned = !vgraph_batch_cache_publish (ctx, algo_id, params_hash, copy, copy_size);
      return;
    }
  vgraph_batch_cache_abort (ctx);
  out->payload = values;	/* workspace-backed, valid until cleanup */
}

/* As above, for a payload made of two arrays.  Unlike the single-array
 * case there is no workspace-backed fallback: the two source arrays are
 * not adjacent in the workspace, so a copy is the only way to hand them
 * out as one payload.  Returns false when that copy could not be made,
 * which the callback surfaces as an out-of-memory error rather than as a
 * silently empty result. */
static bool
vgraph_batch_finish_pair (algo_context_t *ctx, uint32_t algo_id,
    uint64_t params_hash, const void *first, const void *second, uint64_t node_count, bool is_double, vgraph_batch_result_t *out)
{
  size_t half, size;
  char *copy;

  out->is_double = is_double;
  out->node_count = node_count;
  out->payload = NULL;
  out->owned = false;
  out->size = 0;
  if (!first || !second || !node_count || node_count > (((uint64_t) 1) << 39))
    {
      vgraph_batch_cache_abort (ctx);
      return !node_count;	/* an empty graph is not a failure */
    }
  half = (size_t) node_count *sizeof (uint64_t);
  size = half * 2;
  copy = (char *) dk_alloc (size);
  if (!copy)
    {
      vgraph_batch_cache_abort (ctx);
      return false;
    }
  memcpy (copy, first, half);
  memcpy (copy + half, second, half);
  out->payload = copy;
  out->size = size;
  out->owned = !vgraph_batch_cache_publish (ctx, algo_id, params_hash, copy, size);
  return true;
}

/* True batch execution for whole-graph algorithms (PageRank, eigenvector,
 * WCC, SCC, community_id, per-node triangle_count).  Instead of calling
 * the scalar BIF once per row, this function:
 *   1. Resolves all node IRIs in one batch.
 *   2. Sets up the algorithm context once (shared snapshot via cache).
 *   3. Runs the algorithm once, or reuses a cached whole-graph result.
 *   4. Maps results back to each row via the O(1) snapshot node hash.
 *
 * For per-node/per-pair algorithms (degree, shortest_path, BFS, Jaccard),
 * the per-row scalar path via vgraph_vec_apply is still used. */
static void
vgraph_vec_whole_graph (caddr_t *qst, caddr_t *err_ret,
    state_slot_t **args, state_slot_t *ret, const char *bif_name, const vgraph_whole_graph_algo_t *algo)
{
  QNCAST (query_instance_t, qi, qst);
  int n_sets = qi->qi_n_sets;
  int nargs = BOX_ELEMENTS (args);
  int row_arg = algo->row_arg_index;
  data_col_t *node_col;
  graph_node_id_t *batch_ids;
  graph_node_id_t src_node = GRAPH_NODE_ID_INVALID;
  caddr_t graph_arg, pred_arg;
  algo_context_t ctx;
  graph_error_t gerr;
  vgraph_batch_result_t br;
  int set;

  memset (&br, 0, sizeof (br));

  if (!ret || SSL_VEC != ret->ssl_type || n_sets < vgraph_min_batch)
    {
      *err_ret = BIF_NOT_VECTORED;
      return;
    }
  if (row_arg >= nargs || SSL_VEC != args[row_arg]->ssl_type)
    {
      *err_ret = BIF_NOT_VECTORED;
      return;
    }

  node_col = QST_BOX (data_col_t *, qst, args[row_arg]->ssl_index);
  batch_ids = (graph_node_id_t *) mp_alloc_box (qi->qi_mp, n_sets * sizeof (graph_node_id_t), DV_BIN);
  if (!batch_ids)
    {
      *err_ret = BIF_NOT_VECTORED;
      return;
    }
  if (vgraph_iri_to_id_batch (qst, node_col, n_sets, batch_ids, err_ret) != GRAPH_OK)
    {
      if (!*err_ret)
	*err_ret = BIF_NOT_VECTORED;
      return;
    }

  if (row_arg > 0)
    {
      /* Source-keyed traversal.  One distance vector serves the whole
       * batch only if every row asks about the same source and the
       * remaining arguments -- graph, predicate, direction -- are
       * constant for the batch, because they are what the cache key is
       * built from.  When they are not, falling back to the row loop is
       * still cheap: the scalar path consults the same source-keyed
       * result cache, so each distinct source costs one traversal
       * rather than one per row. */
      int i;
      for (i = 0; i < nargs; i++)
	{
	  if (i == row_arg || i == 0)
	    continue;
	  if (SSL_VEC == args[i]->ssl_type)
	    {
	      *err_ret = BIF_NOT_VECTORED;
	      return;
	    }
	}
      if (SSL_VEC == args[0]->ssl_type)
	{
	  data_col_t *src_col = QST_BOX (data_col_t *, qst, args[0]->ssl_index);
	  graph_node_id_t *src_ids = (graph_node_id_t *) mp_alloc_box (qi->qi_mp, n_sets * sizeof (graph_node_id_t), DV_BIN);
	  if (!src_ids)
	    {
	      *err_ret = BIF_NOT_VECTORED;
	      return;
	    }
	  if (vgraph_iri_to_id_batch (qst, src_col, n_sets, src_ids, err_ret) != GRAPH_OK)
	    {
	      if (!*err_ret)
		*err_ret = BIF_NOT_VECTORED;
	      return;
	    }
	  for (set = 0; set < n_sets; set++)
	    {
	      if (DC_IS_NULL (src_col, set) || src_ids[set] != src_ids[0])
		{
		  *err_ret = BIF_NOT_VECTORED;
		  return;
		}
	    }
	  src_node = src_ids[0];
	}
      else
	{
	  caddr_t src_arg = bif_arg (qst, args, 0, bif_name);
	  if (!src_arg || DV_TYPE_OF (src_arg) == DV_DB_NULL)
	    {
	      *err_ret = BIF_NOT_VECTORED;
	      return;
	    }
	  src_node = vgraph_node_to_id_ex (src_arg, qst);
	}
      if (GRAPH_NODE_ID_INVALID == src_node)
	{
	  *err_ret = BIF_NOT_VECTORED;
	  return;
	}
    }

  graph_arg = nargs > row_arg + 1 ? bif_arg (qst, args, row_arg + 1, bif_name) : NULL;
  pred_arg = nargs > row_arg + 2 ? bif_arg (qst, args, row_arg + 2, bif_name) : NULL;

  gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGVB01",
	  "%s: failed to load graph: %s", bif_name, vgraph_load_reason (gerr, qst));
      return;
    }
  ctx.src_node = src_node;	/* setup_algo_context() zeroes ctx */

  ctx.ws_size = algo->workspace_size (ctx.snapshot);

  gerr = algo->compute (qst, err_ret, args, &ctx, &br);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_CONVERGENCE)
    {
      vgraph_payload_release (&br);
      if (!*err_ret)
	{
	  /* A workspace that does not fit is reported as itself: the
	   * limit is the one part of this an operator can act on, and
	   * ctx.workspace still being NULL is what distinguishes it. */
	  if (GRAPH_ERR_OUT_OF_MEMORY == gerr && !ctx.workspace)
	    *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, "VGVB02",
		"%s: workspace of %lu bytes exceeds [Graph] MaxWorkspace (%lu bytes)",
		bif_name, (unsigned long) ctx.ws_size, (unsigned long) vgraph_workspace_limit ());
	  else
	    *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGVB03",
		"%s: algorithm failed: %s", bif_name, graph_error_string (gerr));
	}
      cleanup_algo_context (&ctx);
      return;
    }

  /* Map results back to each row via the snapshot's O(1) node hash. */
  {
    data_col_t *ret_dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
    dc_reset (ret_dc);
    for (set = 0; set < n_sets; set++)
      {
	if (DC_IS_NULL (node_col, set))
	  {
	    dc_set_null (ret_dc, set);
	    continue;
	  }
	uint64_t idx = find_node_index (ctx.snapshot, batch_ids[set]);
	if (UINT64_MAX == idx || idx >= br.node_count || !br.payload)
	  {
	    dc_set_null (ret_dc, set);
	    continue;
	  }
	if (br.is_double)
	  dc_set_double (ret_dc, set, ((const double *) br.payload)[idx + (algo->payload_half ? br.node_count : 0)]);
	else
	  {
	    uint64_t v = ((const uint64_t *) br.payload)[idx];
	    dc_set_long (ret_dc, set, algo->as_reach ? (v != UINT64_MAX) : (boxint) v);
	  }
      }
    ret_dc->dc_n_values = n_sets;
  }
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);
}

/* Compute callback: PageRank.  Parses the optional damping / max_iter /
 * tolerance arguments (positions and validation as the scalar BIF). */
static graph_error_t
vgraph_batch_pagerank_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, algo_context_t *ctx, vgraph_batch_result_t *out)
{
  int nargs = BOX_ELEMENTS (args);
  graph_pagerank_params_t params = GRAPH_PAGERANK_DEFAULT;
  graph_pagerank_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash;

  if (nargs > 3)
    {
      caddr_t a = bif_arg (qst, args, 3, "GRAPH_PAGERANK");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  params.damping = vgraph_box_to_double (a);
	  if (params.damping <= 0.0 || params.damping >= 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPR06",
		  "GRAPH_PAGERANK: damping must be in (0,1), got %g", params.damping);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	}
    }
  if (nargs > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_PAGERANK");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  /* Accept any numeric box type (SPARQL emits DV_LONG_INT but
	   * SQL callers may pass other numeric types). */
	  double mi_d = vgraph_box_to_double (a);
	  int64_t mi = (int64_t) mi_d;
	  if (mi_d != (double) mi || mi < 1 || mi > 100000)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPR07",
		  "GRAPH_PAGERANK: max_iter must be an integer in [1,100000], got %g", mi_d);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	  params.max_iterations = (int) mi;
	}
    }
  if (nargs > 5)
    {
      caddr_t a = bif_arg (qst, args, 5, "GRAPH_PAGERANK");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  params.epsilon = vgraph_box_to_double (a);
	  if (params.epsilon <= 0.0 || params.epsilon >= 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPR08",
		  "GRAPH_PAGERANK: tolerance must be in (0,1), got %g", params.epsilon);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	}
    }

  if (nargs > 6)
    {
      caddr_t a = bif_arg (qst, args, 6, "GRAPH_PAGERANK");
      /* No `a &&` here.  Virtuoso boxes a small integer inline, so the
       * integer 0 -- a legal value for this flag, unlike damping or
       * max_iter -- is the same pointer as C NULL and a pointer test
       * skips the argument, leaving the default.  It cost `directed 0`
       * over a SERVICE result: accepted, range-checked, then ignored,
       * while `directed 0.0` worked.  DV_TYPE_OF() already reports a
       * real SQL NULL as DV_DB_NULL, which is a box. */
      if (DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  double d = vgraph_box_to_double (a);
	  if (d != 0.0 && d != 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPR09",
		  "GRAPH_PAGERANK: directed must be 0 or 1, got %g", d);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	  params.directed = (d != 0.0);
	}
    }

  hash = vgraph_params_hash_double (vgraph_params_hash_int (vgraph_params_hash_double (0, params.epsilon),
	  params.max_iterations), params.damping);
  /* Part of the key: an undirected run must not be served the directed
   * vector that a previous call left in the slot. */
  hash = vgraph_params_hash_int (hash, params.directed ? 1 : 0);
  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_PAGERANK, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, true, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_pagerank (ctx->snapshot, &params, NULL, ws, &result);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_CONVERGENCE)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_double (ctx, GRAPH_ALGO_PAGERANK, hash, result.scores, result.node_count, out);
  return gerr;
}

/* Compute callback: eigenvector centrality.  Parses the optional
 * max_iter / tolerance arguments (positions and validation as the
 * scalar BIF). */
static graph_error_t
vgraph_batch_eigenvector_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, vgraph_batch_result_t *out)
{
  int nargs = BOX_ELEMENTS (args);
  graph_eigenvector_params_t params = GRAPH_EIGENVECTOR_DEFAULT;
  graph_eigenvector_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash;

  if (nargs > 3)
    {
      caddr_t a = bif_arg (qst, args, 3, "GRAPH_EIGENVECTOR_CENTRALITY");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  /* Accept any numeric box type (SPARQL emits DV_LONG_INT but
	   * SQL callers may pass other numeric types). */
	  double mi_d = vgraph_box_to_double (a);
	  int64_t mi = (int64_t) mi_d;
	  if (mi_d != (double) mi || mi < 1 || mi > 100000)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGEIG06",
		  "GRAPH_EIGENVECTOR_CENTRALITY: max_iter must be an integer in [1,100000], got %g", mi_d);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	  params.max_iterations = (int) mi;
	}
    }
  if (nargs > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_EIGENVECTOR_CENTRALITY");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  params.epsilon = vgraph_box_to_double (a);
	  if (params.epsilon <= 0.0 || params.epsilon >= 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGEIG07",
		  "GRAPH_EIGENVECTOR_CENTRALITY: tolerance must be in (0,1), got %g", params.epsilon);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	}
    }

  hash = vgraph_params_hash_int (vgraph_params_hash_double (0, params.epsilon), params.max_iterations);
  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_EIGENVECTOR, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, true, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_eigenvector (ctx->snapshot, &params, NULL, ws, &result);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_CONVERGENCE)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_double (ctx, GRAPH_ALGO_EIGENVECTOR, hash, result.scores, result.node_count, out);
  return gerr;
}

/* Compute callback: HITS.  Parses the optional max_iter / tolerance
 * arguments (positions and validation as the eigenvector BIF, which is
 * the other power iteration and takes the same two).
 *
 * One run produces both vectors, and they are cached as one two-array
 * payload -- hub first, authority second -- under a single key.  The two
 * predicates then differ only in the descriptor's payload_half, so a
 * query that selects both reads one cached result rather than iterating
 * twice.  There is no `normalized` option for the same reason
 * eigenvector has none: the iteration divides by the L2 norm on every
 * pass, and the convergence test compares successive normalised
 * iterates, so an unnormalised vector is not a presentation choice but a
 * different (non-terminating) algorithm. */
static graph_error_t
vgraph_batch_hits_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, algo_context_t *ctx, vgraph_batch_result_t *out)
{
  int nargs = BOX_ELEMENTS (args);
  graph_hits_params_t params = GRAPH_HITS_DEFAULT;
  graph_hits_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash;

  if (nargs > 3)
    {
      caddr_t a = bif_arg (qst, args, 3, "GRAPH_HITS");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  double mi_d = vgraph_box_to_double (a);
	  int64_t mi = (int64_t) mi_d;
	  if (mi_d != (double) mi || mi < 1 || mi > 100000)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGHIT06",
		  "GRAPH_HITS: max_iter must be an integer in [1,100000], got %g", mi_d);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	  params.max_iterations = (int) mi;
	}
    }
  if (nargs > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_HITS");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  params.epsilon = vgraph_box_to_double (a);
	  if (params.epsilon <= 0.0 || params.epsilon >= 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGHIT07",
		  "GRAPH_HITS: tolerance must be in (0,1), got %g", params.epsilon);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	}
    }

  hash = vgraph_params_hash_int (vgraph_params_hash_double (0, params.epsilon), params.max_iterations);
  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_HITS, hash, false, &res))
    {
      vgraph_batch_fill_cached_pair (&res, true, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_hits (ctx->snapshot, &params, NULL, ws, &result);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_CONVERGENCE)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  /* Unlike the single-array finishers there is no workspace-backed
   * fallback here -- hub and authority are not adjacent in the
   * workspace -- so a failed copy is an error rather than a silently
   * empty result. */
  if (!vgraph_batch_finish_pair (ctx, GRAPH_ALGO_HITS, hash,
	  result.hub_scores, result.authority_scores, result.node_count, true, out))
    return GRAPH_ERR_OUT_OF_MEMORY;
  return gerr;
}

/* Compute callback: weakly connected components.  No optional arguments. */
static graph_error_t
vgraph_batch_wcc_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, algo_context_t *ctx, vgraph_batch_result_t *out)
{
  (void) qst;
  (void) err_ret;
  (void) args;
  graph_wcc_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash = 0;

  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_WCC, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, false, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_wcc (ctx->snapshot, NULL, ws, &result);
  if (gerr != GRAPH_OK)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_int (ctx, GRAPH_ALGO_WCC, hash, result.component_ids, result.node_count, out);
  return gerr;
}

/* Compute callback: strongly connected components.  No optional args. */
static graph_error_t
vgraph_batch_scc_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, algo_context_t *ctx, vgraph_batch_result_t *out)
{
  (void) qst;
  (void) err_ret;
  (void) args;
  graph_scc_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash = 0;

  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_SCC, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, false, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_scc (ctx->snapshot, NULL, ws, &result);
  if (gerr != GRAPH_OK)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_int (ctx, GRAPH_ALGO_SCC, hash, result.component_ids, result.node_count, out);
  return gerr;
}

/* Compute callback: Louvain community detection.  Parses the optional
 * resolution argument (position and validation as the scalar BIF). */
static graph_error_t
vgraph_batch_community_id_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, vgraph_batch_result_t *out)
{
  int nargs = BOX_ELEMENTS (args);
  graph_louvain_params_t params = GRAPH_LOUVAIN_DEFAULT;
  graph_louvain_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash;

  if (nargs > 3)
    {
      caddr_t a = bif_arg (qst, args, 3, "GRAPH_COMMUNITY_ID");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  params.resolution = vgraph_box_to_double (a);
	  if (params.resolution <= 0.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGCOM06",
		  "GRAPH_COMMUNITY_ID: resolution must be > 0, got %g", params.resolution);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	}
    }

  hash = vgraph_params_hash_double (0, params.resolution);
  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_LOUVAIN, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, false, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_louvain (ctx->snapshot, &params, NULL, ws, &result);
  if (gerr != GRAPH_OK)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_int (ctx, GRAPH_ALGO_LOUVAIN, hash, result.community_ids, result.node_count, out);
  return gerr;
}

/* Compute callback: per-node triangle counts.  No optional arguments. */
static graph_error_t
vgraph_batch_triangles_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, vgraph_batch_result_t *out)
{
  (void) qst;
  (void) err_ret;
  (void) args;
  graph_triangles_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash = 0;

  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_TRIANGLES, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, false, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_triangles (ctx->snapshot, NULL, ws, &result);
  if (gerr != GRAPH_OK)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_int (ctx, GRAPH_ALGO_TRIANGLES, hash, result.triangle_counts, result.node_count, out);
  return gerr;
}

/* Compute callback: betweenness.  Parses the optional normalized /
 * directed arguments (positions and validation as the scalar BIF). */
static graph_error_t
vgraph_batch_betweenness_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, vgraph_batch_result_t *out)
{
  int nargs = BOX_ELEMENTS (args);
  graph_betweenness_params_t params = GRAPH_BETWEENNESS_DEFAULT;
  graph_betweenness_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash;
  (void) err_ret;

  if (nargs > 3)
    params.normalized = (0 != bif_long_arg (qst, args, 3, "GRAPH_BETWEENNESS"));
  if (nargs > 4)
    params.directed = (0 != bif_long_arg (qst, args, 4, "GRAPH_BETWEENNESS"));

  hash = vgraph_params_hash_int (vgraph_params_hash_int (0, params.normalized), params.directed);
  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_BETWEENNESS, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, true, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_betweenness (ctx->snapshot, &params, NULL, ws, &result);
  if (gerr != GRAPH_OK)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_double (ctx, GRAPH_ALGO_BETWEENNESS, hash, result.scores, result.node_count, out);
  return gerr;
}

/* Compute callbacks for the weighted whole-graph algorithms.
 *
 * These exist so a weighted score is computed once per (snapshot,
 * parameters, weights) rather than once per row.  Betweenness, PageRank
 * and eigenvector each produce a vector covering every node in one pass,
 * and the unweighted forms have always been served that way; the
 * weighted ones called the algorithm directly, so a query over N nodes
 * ran N full passes.  Nothing in the answers showed it -- a weighted
 * betweenness over 1,762 rail sections, 2.9 s for one call, was still
 * running after fifteen minutes.
 *
 * The weight source is part of the cache key, through the weight
 * lookup's build id: two calls that agree on parameters but weigh the
 * edges differently are different questions.  They also carry their own
 * GRAPH_ALGO_* ids, so a weighted vector can never be handed to an
 * unweighted caller.
 *
 * ctx->weight_lookup is set by the BIF before the driver is entered. */
static graph_error_t
vgraph_batch_betweenness_w_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, vgraph_batch_result_t *out)
{
  int nargs = BOX_ELEMENTS (args);
  graph_betweenness_params_t params = GRAPH_BETWEENNESS_DEFAULT;
  graph_betweenness_result_t result;
  const weight_lookup_t *wl = (const weight_lookup_t *) ctx->weight_lookup;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash;
  (void) err_ret;

  if (nargs > 4)
    params.normalized = (0 != bif_long_arg (qst, args, 4, "GRAPH_BETWEENNESS_WEIGHTED"));
  if (nargs > 5)
    params.directed = (0 != bif_long_arg (qst, args, 5, "GRAPH_BETWEENNESS_WEIGHTED"));

  /* An undirected run walks each edge both ways, so it will ask what
   * (object, subject) weighs.  The lookup is keyed on the edge as
   * stored, and without this that probe misses and the reverse of every
   * edge silently weighs the default of 1.  Unit weights hide it
   * exactly, which is why it survived so long. */
  ((weight_lookup_t *) wl)->symmetric = !params.directed;

  hash = vgraph_params_hash_int (vgraph_params_hash_int (0, params.normalized), params.directed);
  hash = vgraph_params_hash_int (hash, (int64_t) weight_lookup_build_id (wl));
  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_BETWEENNESS_W, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, true, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_betweenness_weighted (ctx->snapshot, &params, NULL, weighted_edge_lookup, (void *) wl, ws, &result);
  if (gerr != GRAPH_OK)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_double (ctx, GRAPH_ALGO_BETWEENNESS_W, hash, result.scores, result.node_count, out);
  return gerr;
}

static graph_error_t
vgraph_batch_pagerank_w_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, vgraph_batch_result_t *out)
{
  int nargs = BOX_ELEMENTS (args);
  graph_pagerank_params_t params = GRAPH_PAGERANK_DEFAULT;
  graph_pagerank_result_t result;
  const weight_lookup_t *wl = (const weight_lookup_t *) ctx->weight_lookup;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash;
  (void) err_ret;

  if (nargs > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_PAGERANK_WEIGHTED");
      if (DV_DB_NULL != DV_TYPE_OF (a))
	params.damping = vgraph_box_to_double (a);
    }
  if (nargs > 5)
    {
      caddr_t a = bif_arg (qst, args, 5, "GRAPH_PAGERANK_WEIGHTED");
      if (DV_DB_NULL != DV_TYPE_OF (a))
	params.max_iterations = (int) unbox (a);
    }
  if (nargs > 6)
    {
      caddr_t a = bif_arg (qst, args, 6, "GRAPH_PAGERANK_WEIGHTED");
      if (DV_DB_NULL != DV_TYPE_OF (a))
	params.epsilon = vgraph_box_to_double (a);
    }
  if (nargs > 7)
    {
      caddr_t a = bif_arg (qst, args, 7, "GRAPH_PAGERANK_WEIGHTED");
      if (DV_DB_NULL != DV_TYPE_OF (a))
	params.directed = (0 != unbox (a));
    }

  hash = vgraph_params_hash_double (vgraph_params_hash_int (vgraph_params_hash_double (0, params.epsilon),
	  params.max_iterations), params.damping);
  /* An undirected run walks each edge both ways, so it will ask what
   * (object, subject) weighs.  The lookup is keyed on the edge as
   * stored, and without this that probe misses and the reverse of every
   * edge silently weighs the default of 1.  Unit weights hide it
   * exactly, which is why it survived so long. */
  ((weight_lookup_t *) wl)->symmetric = !params.directed;

  hash = vgraph_params_hash_int (hash, params.directed ? 1 : 0);
  hash = vgraph_params_hash_int (hash, (int64_t) weight_lookup_build_id (wl));
  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_PAGERANK_W, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, true, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_pagerank_weighted (ctx->snapshot, &params, NULL, weighted_edge_lookup, (void *) wl, ws, &result);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_CONVERGENCE)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_double (ctx, GRAPH_ALGO_PAGERANK_W, hash, result.scores, result.node_count, out);
  return GRAPH_OK;
}

static graph_error_t
vgraph_batch_eigenvector_w_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, vgraph_batch_result_t *out)
{
  int nargs = BOX_ELEMENTS (args);
  graph_eigenvector_params_t params = GRAPH_EIGENVECTOR_DEFAULT;
  graph_eigenvector_result_t result;
  const weight_lookup_t *wl = (const weight_lookup_t *) ctx->weight_lookup;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash;
  (void) err_ret;

  if (nargs > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_EIGENVECTOR_WEIGHTED");
      if (DV_DB_NULL != DV_TYPE_OF (a))
	params.max_iterations = (int) unbox (a);
    }
  if (nargs > 5)
    {
      caddr_t a = bif_arg (qst, args, 5, "GRAPH_EIGENVECTOR_WEIGHTED");
      if (DV_DB_NULL != DV_TYPE_OF (a))
	params.epsilon = vgraph_box_to_double (a);
    }

  hash = vgraph_params_hash_int (vgraph_params_hash_double (0, params.epsilon), params.max_iterations);
  hash = vgraph_params_hash_int (hash, (int64_t) weight_lookup_build_id (wl));
  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_EIGENVECTOR_W, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, true, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_eigenvector_weighted (ctx->snapshot, &params, NULL, weighted_edge_lookup, (void *) wl, ws, &result);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_CONVERGENCE)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_double (ctx, GRAPH_ALGO_EIGENVECTOR_W, hash, result.scores, result.node_count, out);
  return GRAPH_OK;
}

/* Compute callback: CDLP label propagation.  Parses the optional
 * max_iterations argument (position and validation as the scalar BIF). */
static graph_error_t
vgraph_batch_labelprop_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, vgraph_batch_result_t *out)
{
  int nargs = BOX_ELEMENTS (args);
  graph_labelprop_params_t params = GRAPH_LABELPROP_DEFAULT;
  graph_labelprop_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash;

  if (nargs > 3)
    {
      caddr_t a = bif_arg (qst, args, 3, "GRAPH_LABEL_PROPAGATION");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  params.max_iterations = (int) unbox (a);
	  if (params.max_iterations < 1 || params.max_iterations > 100000)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLPA06",
		  "GRAPH_LABEL_PROPAGATION: max_iter must be in [1,100000], got %d", params.max_iterations);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	}
    }

  if (nargs > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_LABEL_PROPAGATION");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  int64_t lf = unbox (a);
	  if (lf < 0 || lf > 1)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLPA07",
		  "GRAPH_LABEL_PROPAGATION: label_form must be 0 (dense) or 1 (representative vertex), got %ld", (long) lf);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	  params.label_form = (graph_labelprop_label_form_t) lf;
	}
    }

  hash = vgraph_params_hash_int (0, params.max_iterations);
  /* The two label forms are different vectors over the same graph, so
   * they must not share a cache slot. */
  hash = vgraph_params_hash_int (hash, (int64_t) params.label_form);
  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_LABEL_PROP, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, false, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_labelprop (ctx->snapshot, &params, NULL, ws, &result);
  if (gerr != GRAPH_OK)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_int (ctx, GRAPH_ALGO_LABEL_PROP, hash, result.labels, result.node_count, out);
  return gerr;
}

/* Compute callback: local clustering coefficient.  No optional args. */
static graph_error_t
vgraph_batch_clustering_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, vgraph_batch_result_t *out)
{
  graph_clustering_params_t params = GRAPH_CLUSTERING_DEFAULT;
  graph_clustering_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  uint64_t hash = 0;

  /* Argument 3 in both the (node, graph, pred, directed) and the
   * (graph, pred, -, directed) form, so the dual dispatch above does
   * not move it. */
  if (BOX_ELEMENTS (args) > 3)
    {
      caddr_t a = bif_arg (qst, args, 3, "GRAPH_CLUSTERING_COEFFICIENT");
      /* No `a &&` here.  Virtuoso boxes a small integer inline, so the
       * integer 0 -- a legal value for this flag, unlike damping or
       * max_iter -- is the same pointer as C NULL and a pointer test
       * skips the argument, leaving the default.  It cost `directed 0`
       * over a SERVICE result: accepted, range-checked, then ignored,
       * while `directed 0.0` worked.  DV_TYPE_OF() already reports a
       * real SQL NULL as DV_DB_NULL, which is a box. */
      if (DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  int64_t d = unbox (a);
	  if (d < 0 || d > 1)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLCC05",
		  "GRAPH_CLUSTERING_COEFFICIENT: directed must be 0 or 1, got %ld", (long) d);
	      return GRAPH_ERR_INVALID_PARAM;
	    }
	  params.directed = (d != 0);
	}
    }
  hash = vgraph_params_hash_int (0, params.directed ? 1 : 0);

  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_CLUSTERING, hash, false, &res))
    {
      vgraph_batch_fill_cached (&res, true, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_clustering (ctx->snapshot, &params, NULL, ws, &result);
  if (gerr != GRAPH_OK)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  vgraph_batch_finish_double (ctx, GRAPH_ALGO_CLUSTERING, hash, result.coefficients, result.node_count, out);
  return gerr;
}

/* Compute callback: one BFS from ctx->src_node.
 *
 * BFS already fills a distance for every node and then had one number read
 * out of it, so a query with one source and many targets re-ran the whole
 * traversal per row: O(V*(V+E)) where it should be O(V+E).  Keying the
 * result cache on the source as well as the parameters makes the varying
 * target an index into a vector computed once.
 *
 * The payload is {distances[V], parents[V]}: the distances answer the
 * length forms, the parents let GRAPH_SHORTEST_PATH rebuild a path from
 * the same cached traversal instead of running its own. */
/* Dividing a degree by n-1 is what "degree centrality" means in Freeman's
   sense and what NetworkX returns; the raw count is what Neo4j GDS returns
   and what this has always returned, so raw stays the default and the flag
   is the way to ask for the other.  n is snapshot->node_map_count, an O(1)
   field -- the count of distinct nodes, not the capacity -- so normalizing
   costs a divide and no extra pass over anything. */
static double
vgraph_normalize_by_order (double v, const graph_snapshot_t *snap, int normalized)
{
  uint64_t n;
  if (!normalized || !snap)
    return v;
  n = snap->node_map_count;
  return (n > 1) ? v / (double) (n - 1) : 0.0;
}

/* A direction argument, as an integer or as a name.
 *
 * There are two integer encodings here and neither can be renumbered
 * without silently changing what a shipped query returns: the traversals
 * (bfs, dfs, shortest_path, closeness, harmonic) read 0 as outgoing,
 * while degree_centrality reads 0 as both -- each being the useful
 * default for its own measure.  So the same literal means different
 * things in two calls, and nothing can warn about it.
 *
 * The names cannot be ambiguous, so they are the portable way to ask:
 * 'out', 'in' and 'both' mean the same thing to every predicate, which is
 * exactly what the integer 2 does not.  `enc` says which set of integers
 * the caller speaks; a name ignores it.
 *
 * Tested with DV_TYPE_OF and never as a pointer: Virtuoso boxes small
 * integers inline, so the integer 0 -- a legal direction -- is the same
 * pointer as C NULL and a pointer test would read it as absent. */
typedef enum
{
  VGRAPH_DIRENC_TRAVERSAL = 0,	/* 0 out, 1 in, 2 both */
  VGRAPH_DIRENC_DEGREE = 1	/* 0 both, 1 in, 2 out */
} vgraph_direnc_t;

static int
vgraph_direction_arg (caddr_t a, vgraph_direnc_t enc, graph_direction_t dflt, graph_direction_t *out)
{
  long v;
  if (DV_TYPE_OF (a) == DV_DB_NULL)
    {
      *out = dflt;
      return 0;
    }
  if (DV_STRINGP (a))
    {
      if (!stricmp ((char *) a, "out"))
	{
	  *out = GRAPH_DIR_OUTGOING;
	  return 0;
	}
      if (!stricmp ((char *) a, "in"))
	{
	  *out = GRAPH_DIR_INCOMING;
	  return 0;
	}
      if (!stricmp ((char *) a, "both"))
	{
	  *out = GRAPH_DIR_BOTH;
	  return 0;
	}
      return -1;
    }
  v = (long) unbox (a);
  if (v < 0 || v > 2)
    return -1;
  if (VGRAPH_DIRENC_DEGREE == enc)
    *out = (1 == v) ? GRAPH_DIR_INCOMING : (2 == v) ? GRAPH_DIR_OUTGOING : GRAPH_DIR_BOTH;
  else
    *out = (1 == v) ? GRAPH_DIR_INCOMING : (2 == v) ? GRAPH_DIR_BOTH : GRAPH_DIR_OUTGOING;
  return 0;
}

static graph_error_t
vgraph_batch_bfs_run (algo_context_t *ctx, int direction, vgraph_batch_result_t *out)
{
  graph_bfs_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  graph_direction_t gdir;
  uint64_t hash;

  gdir = (direction == 1) ? GRAPH_DIR_INCOMING : (direction == 2) ? GRAPH_DIR_BOTH : GRAPH_DIR_OUTGOING;
  hash = vgraph_params_hash_int (vgraph_params_hash_int (0, (int64_t) ctx->src_node), direction);
  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_BFS, hash, true, &res))
    {
      vgraph_batch_fill_cached_pair (&res, false, out);
      return GRAPH_OK;
    }

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_bfs (ctx->snapshot, ctx->src_node, gdir, NULL, ws, &result);
  if (gerr != GRAPH_OK)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  if (!vgraph_batch_finish_pair (ctx, GRAPH_ALGO_BFS, hash, result.distances, result.parents, result.node_count, false, out))
    return GRAPH_ERR_OUT_OF_MEMORY;
  return GRAPH_OK;
}

/* GRAPH_BFS(source, target, [graph], [pred], [direction]) */
static graph_error_t
vgraph_batch_bfs_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, algo_context_t *ctx, vgraph_batch_result_t *out)
{
  int nargs = BOX_ELEMENTS (args);
  int direction = 0;

  if (nargs > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_BFS");
      /* No `a &&` here.  Virtuoso boxes a small integer inline, so the
       * integer 0 -- a legal value for this flag, unlike damping or
       * max_iter -- is the same pointer as C NULL and a pointer test
       * skips the argument, leaving the default.  It cost `directed 0`
       * over a SERVICE result: accepted, range-checked, then ignored,
       * while `directed 0.0` worked.  DV_TYPE_OF() already reports a
       * real SQL NULL as DV_DB_NULL, which is a box. */
      graph_direction_t gd;
      if (vgraph_direction_arg (a, VGRAPH_DIRENC_TRAVERSAL, GRAPH_DIR_OUTGOING, &gd))
	{
	  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGBFS06",
	      "GRAPH_BFS: direction must be 0 or 'out', 1 or 'in', 2 or 'both'");
	  return GRAPH_ERR_INVALID_PARAM;
	}
      direction = (int) gd;
    }
  return vgraph_batch_bfs_run (ctx, direction, out);
}

/* GRAPH_SHORTEST_PATH[_LENGTH] with a direction of their own.
 *
 * The weighted forms have always taken one; these did not, so an
 * undirected hop count could not be asked for at all.  The argument sits
 * at a different position in each -- the path form has return_type
 * before it -- so the position is a parameter rather than two copies of
 * the body.
 *
 * direction reaches the cache key through vgraph_batch_bfs_run(), which
 * is what keeps the as-recorded and either-way readings in separate
 * slots rather than the first standing in for the second. */
static graph_error_t
vgraph_batch_bfs_dir_at (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, vgraph_batch_result_t *out, int pos, const char *fname, const char *code)
{
  int nargs = BOX_ELEMENTS (args);
  int direction = 0;

  if (nargs > pos)
    {
      caddr_t a = bif_arg (qst, args, pos, (char *) fname);
      /* No `a &&`: the integer 0 is inline-boxed and shares its pointer
       * with NULL, and 0 is this argument's most common value. */
      graph_direction_t gd;
      if (vgraph_direction_arg (a, VGRAPH_DIRENC_TRAVERSAL, GRAPH_DIR_OUTGOING, &gd))
	{
	  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, (char *) code,
	      "%s: direction must be 0 or 'out', 1 or 'in', 2 or 'both'", fname);
	  return GRAPH_ERR_INVALID_PARAM;
	}
      direction = (int) gd;
    }
  return vgraph_batch_bfs_run (ctx, direction, out);
}

static graph_error_t
vgraph_batch_spl_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, algo_context_t *ctx, vgraph_batch_result_t *out)
{
  return vgraph_batch_bfs_dir_at (qst, err_ret, args, ctx, out, 4, "GRAPH_SHORTEST_PATH_LENGTH", "VGSL06");
}

static graph_error_t
vgraph_batch_sp_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, algo_context_t *ctx, vgraph_batch_result_t *out)
{
  return vgraph_batch_bfs_dir_at (qst, err_ret, args, ctx, out, 5, "GRAPH_SHORTEST_PATH", "VGSP06");
}

/* GRAPH_SHORTEST_PATH[_LENGTH](from, to, [graph], [pred], ...): always
 * outgoing, so it shares the cache slot GRAPH_BFS fills at direction 0. */
static graph_error_t
vgraph_batch_bfs_out_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, algo_context_t *ctx, vgraph_batch_result_t *out)
{
  (void) qst;
  (void) err_ret;
  (void) args;
  return vgraph_batch_bfs_run (ctx, 0, out);
}

/* Compute callback: SSSP, one Dijkstra from ctx->src_node under
 * ctx->weight_lookup.  The weights are part of the key -- the same source
 * under different weights is a different distance vector -- so the built
 * table is fingerprinted into the hash.  That is O(W) against Dijkstra's
 * O((V+E) log V), so it costs nothing.
 *
 * The per-slot weight arrays add no input to that key.  They are a pure
 * function of the table and of the direction, both of which are already
 * in the hash: the table by its identity or its contents, the direction
 * directly -- and the direction is what sets `symmetric`, which is the
 * only other thing the resolution depends on.  So a cached distance
 * vector can no more be served against changed weights than it could
 * before. */
static graph_error_t
vgraph_batch_sssp_compute (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, algo_context_t *ctx, vgraph_batch_result_t *out)
{
  (void) qst;
  (void) err_ret;
  (void) args;
  graph_dijkstra_result_t result;
  gcache_result_t res;
  graph_error_t gerr;
  void *ws;
  weight_lookup_t *wl = (weight_lookup_t *) ctx->weight_lookup;
  uint64_t hash, i;
  graph_edge_weights_t ew;
  void *ew_token = NULL;

  graph_direction_t gdir = (ctx->weight_direction == 1) ? GRAPH_DIR_INCOMING :
      (ctx->weight_direction == 2) ? GRAPH_DIR_BOTH : GRAPH_DIR_OUTGOING;

  hash = vgraph_params_hash_int (0, (int64_t) ctx->src_node);
  hash = vgraph_params_hash_int (hash, ctx->weight_direction);
  hash = vgraph_params_hash_double (hash, wl ? wl->default_weight : 1.0);
  hash = vgraph_params_hash_int (hash, wl ? (int64_t) wl->count : 0);
  if (wl && wl->from_graph)
    {
      /* A table read out of a graph is determined by where it was read
       * from, so its identity costs three hashes rather than one per
       * entry.  At a weight per edge the difference is the whole call. */
      hash = vgraph_params_hash_int (hash, (int64_t) wl->src_graph_iri);
      hash = vgraph_params_hash_int (hash, (int64_t) wl->src_pred_iri);
      hash = vgraph_params_hash_int (hash, (int64_t) wl->src_generation);
    }
  else if (wl)
    {
      for (i = 0; i < wl->count; i++)
	{
	  hash = vgraph_params_hash_int (hash, (int64_t) wl->entries[i].subject);
	  hash = vgraph_params_hash_int (hash, (int64_t) wl->entries[i].object);
	  hash = vgraph_params_hash_double (hash, wl->entries[i].weight);
	}
    }

  if (1 == vgraph_batch_cache_lookup (ctx, GRAPH_ALGO_DIJKSTRA, hash, true, &res))
    {
      vgraph_batch_fill_cached_pair (&res, true, out);
      return GRAPH_OK;
    }

  /* Resolve the table into one weight per CSR slot before the traversal
   * starts, so a relaxation is an indexed load rather than a search.
   * weighted_edge_lookup stays the fallback: it is what covers an edge
   * with no slot, and what runs when the arrays are declined. */
  vgraph_edge_weights_get (ctx, wl, &ew, &ew_token);

  ws = vgraph_ws (ctx);
  if (!ws)
    return GRAPH_ERR_OUT_OF_MEMORY;
  gerr = graph_algo_dijkstra (ctx->snapshot, ctx->src_node, gdir, NULL,
      weighted_edge_lookup, wl, ew_token ? &ew : NULL, ws, &result);
  vgraph_edge_weights_unref (ew_token);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_NOT_FOUND)
    {
      vgraph_batch_cache_abort (ctx);
      return gerr;
    }
  if (!vgraph_batch_finish_pair (ctx, GRAPH_ALGO_DIJKSTRA, hash, result.distances, result.parents, result.node_count, true, out))
    return GRAPH_ERR_OUT_OF_MEMORY;
  return gerr;
}

/* The whole-graph algorithm table.  The scalar BIFs and the vectored
 * wrappers both drive these, so a whole-graph algorithm runs at most once
 * per (snapshot, parameters) however it is called. */
static const vgraph_whole_graph_algo_t vgraph_wg_pagerank = {
  vgraph_batch_pagerank_compute, graph_algo_pagerank_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_betweenness = {
  vgraph_batch_betweenness_compute, graph_algo_betweenness_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_betweenness_w = {
  vgraph_batch_betweenness_w_compute, graph_algo_betweenness_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_pagerank_w = {
  vgraph_batch_pagerank_w_compute, graph_algo_pagerank_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_eigenvector_w = {
  vgraph_batch_eigenvector_w_compute, graph_algo_eigenvector_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_eigenvector = {
  vgraph_batch_eigenvector_compute, graph_algo_eigenvector_workspace_size, 0, 0
};

/* Two readings of one HITS run: same compute, same cache key, different
 * half of the payload. */
static const vgraph_whole_graph_algo_t vgraph_wg_hits_hub = {
  vgraph_batch_hits_compute, graph_algo_hits_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_hits_auth = {
  vgraph_batch_hits_compute, graph_algo_hits_workspace_size, 0, 1
};

static const vgraph_whole_graph_algo_t vgraph_wg_wcc = {
  vgraph_batch_wcc_compute, graph_algo_wcc_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_scc = {
  vgraph_batch_scc_compute, graph_algo_scc_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_community_id = {
  vgraph_batch_community_id_compute, graph_algo_louvain_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_triangles = {
  vgraph_batch_triangles_compute, graph_algo_triangles_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_labelprop = {
  vgraph_batch_labelprop_compute, graph_algo_labelprop_workspace_size, 0, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_clustering = {
  vgraph_batch_clustering_compute, graph_algo_clustering_workspace_size, 0, 0
};

/* Source-keyed: args[0] is the source, args[1] the target a row maps on. */
static const vgraph_whole_graph_algo_t vgraph_wg_bfs = {
  vgraph_batch_bfs_compute, graph_algo_bfs_workspace_size, 1, 0, 0
};

/* Same compute callback as bfs, so the two share the cache entry as well
   as the traversal; only the reading differs. */
static const vgraph_whole_graph_algo_t vgraph_wg_dfs = {
  vgraph_batch_bfs_compute, graph_algo_bfs_workspace_size, 1, 0, 1
};

static const vgraph_whole_graph_algo_t vgraph_wg_bfs_out = {
  vgraph_batch_bfs_out_compute, graph_algo_bfs_workspace_size, 1, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_spl = {
  vgraph_batch_spl_compute, graph_algo_bfs_workspace_size, 1, 0
};

static const vgraph_whole_graph_algo_t vgraph_wg_sp = {
  vgraph_batch_sp_compute, graph_algo_bfs_workspace_size, 1, 0
};

/* SSSP has no vectored form (its weight argument is SQL-only), so it maps
 * no rows and keeps row_arg_index 0; the scalar path still reads it out of
 * the source-keyed result cache. */
static const vgraph_whole_graph_algo_t vgraph_wg_sssp = {
  vgraph_batch_sssp_compute, graph_algo_dijkstra_workspace_size, 0, 0
};

/* Scalar entry to the same machinery: allocate the workspace, then run the
 * algorithm's compute callback, which consults the whole-graph result cache
 * first.  Before this, the scalar path re-ran the whole algorithm on every
 * call - a query that was not vectored, or whose batch was under
 * [Graph] MinBatch, paid a full PageRank or Brandes pass per row.
 *
 * On GRAPH_OK the caller reads out->payload[index] and must free it when
 * out->owned; on failure nothing is owned. */
static graph_error_t
vgraph_scalar_whole_graph (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    algo_context_t *ctx, const vgraph_whole_graph_algo_t *algo, vgraph_batch_result_t *out)
{
  memset (out, 0, sizeof (*out));
  /* Sized here, obtained by vgraph_ws() only if the callback misses the
   * result cache and has to run the algorithm. */
  ctx->ws_size = algo->workspace_size (ctx->snapshot);
  return algo->compute (qst, err_ret, args, ctx, out);
}

/* vgraph_scalar_whole_graph() reports a workspace that does not fit as a
 * plain out-of-memory.  The traversal BIFs used to name the limit, which
 * is the one part of that an operator can act on, so keep saying it. */
static void
vgraph_workspace_error (caddr_t *err_ret, const char *bif_name, const char *code, size_t need)
{
  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, (char *) code,
      "%s: workspace of %lu bytes exceeds [Graph] MaxWorkspace (%lu bytes)",
      bif_name, (unsigned long) need, (unsigned long) vgraph_workspace_limit ());
}

/* Read one node's value out of a whole-graph payload. */
static bool
vgraph_payload_double (const vgraph_batch_result_t *br, const graph_snapshot_t *snap, graph_node_id_t node, double *out_value)
{
  uint64_t idx;
  if (!br->payload)
    return false;
  idx = find_node_index (snap, node);
  if (UINT64_MAX == idx || idx >= br->node_count)
    return false;
  *out_value = ((const double *) br->payload)[idx];
  return true;
}

/* As vgraph_payload_double, for whichever half of a two-array payload the
 * caller wants.  half 0 is identical to vgraph_payload_double; half 1
 * reads the array that starts at node_count doubles in.  br->node_count
 * counts the first array only -- vgraph_batch_fill_cached_pair divides
 * the cached size by two -- so the bound check covers both. */
static bool
vgraph_payload_double_at (const vgraph_batch_result_t *br,
    const graph_snapshot_t *snap, graph_node_id_t node, int half, double *out_value)
{
  uint64_t idx;
  if (!br->payload)
    return false;
  idx = find_node_index (snap, node);
  if (UINT64_MAX == idx || idx >= br->node_count)
    return false;
  *out_value = ((const double *) br->payload)[idx + (half ? br->node_count : 0)];
  return true;
}

static bool
vgraph_payload_int (const vgraph_batch_result_t *br, const graph_snapshot_t *snap, graph_node_id_t node, uint64_t *out_value)
{
  uint64_t idx;
  if (!br->payload)
    return false;
  idx = find_node_index (snap, node);
  if (UINT64_MAX == idx || idx >= br->node_count)
    return false;
  *out_value = ((const uint64_t *) br->payload)[idx];
  return true;
}

/* Second half of a two-array payload: the parent vector, indexed by
 * snapshot node index exactly as the distances are. */
static const graph_node_id_t *
vgraph_payload_parents (const vgraph_batch_result_t *br)
{
  if (!br->payload || !br->node_count)
    return NULL;
  return (const graph_node_id_t *) ((const char *) br->payload + (size_t) br->node_count * sizeof (uint64_t));
}

static void
vgraph_payload_release (vgraph_batch_result_t *br)
{
  if (br->owned && br->payload)
    dk_free ((void *) br->payload, br->size);
  br->payload = NULL;
  br->owned = false;
}

/* ============================================================================
 * BIF: GRAPH_DEGREE_CENTRALITY
 * 
 * SQL: GRAPH_DEGREE_CENTRALITY(node_iri, [graph_iri], [predicate_iri], [direction])
 * Returns: DOUBLE PRECISION - degree centrality score
 * ============================================================================ */

static caddr_t
bif_graph_degree_centrality (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  /* Extract arguments */
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_DEGREE_CENTRALITY");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_DEGREE_CENTRALITY") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_DEGREE_CENTRALITY") : NULL;
  caddr_t dir_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_DEGREE_CENTRALITY") : NULL;
  /* normalized: 0=raw count (default), 1=divided by n-1 */
  int dc_normalized = BOX_ELEMENTS (args) > 4 ? (int) bif_long_arg (qst, args, 4, "GRAPH_DEGREE_CENTRALITY") : 0;

  /* Validate node argument */
  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGDEG01", "GRAPH_DEGREE_CENTRALITY: node argument is NULL");
      return NULL;
    }

  /* Parse direction: 0=BOTH (default), 1=IN, 2=OUT -- or the names, which
     mean the same thing here as they do to a traversal, where the same
     integers do not. */
  graph_direction_t gdir = GRAPH_DIR_BOTH;
  if (BOX_ELEMENTS (args) > 3 && vgraph_direction_arg (dir_arg, VGRAPH_DIRENC_DEGREE, GRAPH_DIR_BOTH, &gdir))
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGDEG06",
	  "GRAPH_DEGREE_CENTRALITY: direction must be 0 or 'both', 1 or 'in', 2 or 'out'");
      return NULL;
    }

  /* Use _ex version with query context for proper string IRI resolution */
  graph_node_id_t target_node = vgraph_node_to_id_ex (node_arg, qst);
  if (target_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGDEG02", "GRAPH_DEGREE_CENTRALITY: invalid node IRI");
      return NULL;
    }

  /* Setup algorithm context */
  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGDEG03",
	  "GRAPH_DEGREE_CENTRALITY: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* One node's degree is a CSR row length, so there is no whole-graph pass
   * and no workspace: this used to run graph_algo_degree() over the entire
   * graph and then scan the node map linearly to read one number out of
   * the result. */
  double degree = (double) graph_algo_node_degree (ctx.snapshot, target_node,
      gdir, NULL);
  degree = vgraph_normalize_by_order (degree, ctx.snapshot, dc_normalized);

  cleanup_algo_context (&ctx);

  return box_double (degree);
}

/* ============================================================================
 * BIF: GRAPH_PAGERANK
 * 
 * SQL: GRAPH_PAGERANK(node_iri, [graph_iri], [predicate_iri], [damping], [iterations])
 * Returns: DOUBLE PRECISION - PageRank score
 * ============================================================================ */

static caddr_t
bif_graph_pagerank (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_PAGERANK");
  int nargs = BOX_ELEMENTS (args);
  caddr_t graph_arg = nargs > 1 ? bif_arg (qst, args, 1, "GRAPH_PAGERANK") : NULL;
  caddr_t pred_arg = nargs > 2 ? bif_arg (qst, args, 2, "GRAPH_PAGERANK") : NULL;
  /* Optional: damping, max_iter, tolerance — after graph/predicate.
   * The SPARQL BIND form is bif:pagerank(?node, damping, max_iter) where
   * graph and predicate come from FROM scope.  In SQL the order is
   * (node, graph, pred, damping, max_iter, tolerance). */
  graph_pagerank_params_t params = GRAPH_PAGERANK_DEFAULT;
  graph_pagerank_params_t *pparams = NULL;
  int opt_base = 3;		/* first optional arg index after node, graph, pred */

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGPR01", "GRAPH_PAGERANK: node argument is NULL");
      return NULL;
    }

  graph_node_id_t target_node = vgraph_node_to_id_ex (node_arg, qst);
  if (target_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPR02", "GRAPH_PAGERANK: invalid node IRI");
      return NULL;
    }

  /* Parse optional damping / max_iter / tolerance */
  if (nargs > opt_base)
    {
      caddr_t a = bif_arg (qst, args, opt_base, "GRAPH_PAGERANK");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  params.damping = vgraph_box_to_double (a);
	  if (params.damping <= 0.0 || params.damping >= 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPR06",
		  "GRAPH_PAGERANK: damping must be in (0,1), got %g", params.damping);
	      return NULL;
	    }
	  pparams = &params;
	}
    }
  if (nargs > opt_base + 1)
    {
      caddr_t a = bif_arg (qst, args, opt_base + 1, "GRAPH_PAGERANK");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  int64_t mi = unbox (a);
	  if (mi < 1 || mi > 100000)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPR07",
		  "GRAPH_PAGERANK: max_iter must be in [1,100000], got %ld", (long) mi);
	      return NULL;
	    }
	  params.max_iterations = (int) mi;
	  pparams = &params;
	}
    }
  if (nargs > opt_base + 2)
    {
      caddr_t a = bif_arg (qst, args, opt_base + 2, "GRAPH_PAGERANK");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  params.epsilon = vgraph_box_to_double (a);
	  if (params.epsilon <= 0.0 || params.epsilon >= 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPR08",
		  "GRAPH_PAGERANK: tolerance must be in (0,1), got %g", params.epsilon);
	      return NULL;
	    }
	  pparams = &params;
	}
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGPR03",
	  "GRAPH_PAGERANK: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* Runs through the shared whole-graph driver, so the score vector is
   * taken from the result cache when this snapshot has already been
   * ranked with these parameters.  (void)pparams: the compute callback
   * re-parses the same optional arguments from the same positions; the
   * validation above stays so an invalid value is rejected before the
   * graph is even loaded. */
  (void) pparams;
  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_pagerank, &br);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_CONVERGENCE)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGPR05",
	    "GRAPH_PAGERANK: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  double pr = 0.0;
  bool found = vgraph_payload_double (&br, ctx.snapshot, target_node, &pr);
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);

  if (!found)
    {
      return NEW_DB_NULL;
    }

  return box_double (pr);
}

/* ============================================================================
 * BIF: GRAPH_BETWEENNESS
 * 
 * SQL: GRAPH_BETWEENNESS(node_iri, [graph_iri], [predicate_iri])
 * Returns: DOUBLE PRECISION - betweenness centrality score
 * ============================================================================ */

static caddr_t
bif_graph_betweenness (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_BETWEENNESS");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_BETWEENNESS") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_BETWEENNESS") : NULL;
  /* normalized: 0=raw (default), 1=normalized */
  int normalized = BOX_ELEMENTS (args) > 3 ? (int) bif_long_arg (qst, args, 3, "GRAPH_BETWEENNESS") : 0;
  /* directed: 0=undirected (default), 1=directed */
  int directed = BOX_ELEMENTS (args) > 4 ? (int) bif_long_arg (qst, args, 4, "GRAPH_BETWEENNESS") : 0;

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGBET01", "GRAPH_BETWEENNESS: node argument is NULL");
      return NULL;
    }

  graph_node_id_t target_node = vgraph_node_to_id_ex (node_arg, qst);
  if (target_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGBET02", "GRAPH_BETWEENNESS: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGBET03",
	  "GRAPH_BETWEENNESS: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* Brandes is O(V*E); the shared driver keeps its result in the snapshot
   * result cache so asking for a second node's score is free.
   * (void)normalized/(void)directed: the compute callback re-reads the
   * same arguments, validated above. */
  (void) normalized;
  (void) directed;
  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_betweenness, &br);
  if (gerr != GRAPH_OK)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGBET05",
	    "GRAPH_BETWEENNESS: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  double bet = 0.0;
  bool found = vgraph_payload_double (&br, ctx.snapshot, target_node, &bet);
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);

  if (!found)
    {
      return NEW_DB_NULL;
    }

  return box_double (bet);
}

/* ============================================================================
 * BIF: GRAPH_CLOSENESS
 * 
 * SQL: GRAPH_CLOSENESS(node_iri, [graph_iri], [predicate_iri])
 * Returns: DOUBLE PRECISION - closeness centrality score
 * ============================================================================ */

static caddr_t
bif_graph_closeness (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_CLOSENESS");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_CLOSENESS") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_CLOSENESS") : NULL;
  /* normalized: 0=raw (default), 1=normalized */
  int normalized = BOX_ELEMENTS (args) > 3 ? (int) bif_long_arg (qst, args, 3, "GRAPH_CLOSENESS") : 0;
  /* direction: 0=outgoing (default), 1=incoming, 2=both */
  graph_direction_t cdir = GRAPH_DIR_OUTGOING;
  if (BOX_ELEMENTS (args) > 4 &&
      vgraph_direction_arg (bif_arg (qst, args, 4, "GRAPH_CLOSENESS"), VGRAPH_DIRENC_TRAVERSAL, GRAPH_DIR_OUTGOING, &cdir))
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGCLO06",
	  "GRAPH_CLOSENESS: direction must be 0 or 'out', 1 or 'in', 2 or 'both'");
      return NULL;
    }

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGCLO01", "GRAPH_CLOSENESS: node argument is NULL");
      return NULL;
    }

  graph_node_id_t target_node = vgraph_node_to_id_ex (node_arg, qst);
  if (target_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGCLO02", "GRAPH_CLOSENESS: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGCLO03",
	  "GRAPH_CLOSENESS: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  size_t ws_size = graph_algo_closeness_workspace_size (ctx.snapshot);
  ctx.workspace = vgraph_get_workspace (ws_size);
  if (!ctx.workspace)
    {
      cleanup_algo_context (&ctx);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, "VGCLO04",
	  "GRAPH_CLOSENESS: workspace of %lu bytes exceeds [Graph] MaxWorkspace (%lu bytes)",
	  (unsigned long) ws_size, (unsigned long) vgraph_workspace_limit ());
      return NULL;
    }

  /* Set up params with normalized option */
  graph_closeness_params_t params = GRAPH_CLOSENESS_DEFAULT;
  params.normalized = (normalized != 0);
  params.direction = cdir;

  /* Per-node dispatch: one BFS from the target instead of the full
   * all-sources pass, which cost O(V*(V+E)) per row.  The score is
   * bit-identical to the target's entry in the full result. */
  double clo = 0.0;
  gerr = graph_algo_closeness_single (ctx.snapshot, &params, NULL, ctx.workspace, target_node, &clo);

  cleanup_algo_context (&ctx);

  if (gerr == GRAPH_ERR_NOT_FOUND)
    {
      return NEW_DB_NULL;	/* target is not in the resolved graph */
    }
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGCLO05",
	  "GRAPH_CLOSENESS: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  return box_double (clo);
}

/* ============================================================================
 * BIF: GRAPH_HARMONIC
 *
 * SQL: GRAPH_HARMONIC(node_iri, [graph_iri], [predicate_iri])
 * Returns: DOUBLE PRECISION - harmonic centrality score
 *
 * sum over reachable v != u of 1/d(u,v), following outgoing edges, with
 * unreachable nodes contributing nothing.  Raw, not divided by n-1: the
 * sum is already finite on a disconnected graph, which is the whole
 * reason to prefer harmonic centrality to closeness, so there is no
 * normalisation to choose and no NORMALIZED option.
 *
 * Dispatched per node through graph_algo_closeness_single() rather than
 * through graph_algo_harmonic(), which runs the all-sources pass and
 * would cost O(V*(V+E)) per row to read out one score.  Both reach
 * closeness_compute_one() with the same flag, so the value is identical.
 * ============================================================================ */

static caddr_t
bif_graph_harmonic (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_HARMONIC");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_HARMONIC") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_HARMONIC") : NULL;
  /* direction: 0=outgoing (default), 1=incoming, 2=both -- the same
     encoding closeness uses, harmonic being closeness summed differently */
  graph_direction_t hdir = GRAPH_DIR_OUTGOING;
  /* normalized: 0=raw sum of reciprocals (default), 1=divided by n-1 */
  int h_normalized = BOX_ELEMENTS (args) > 4 ? (int) bif_long_arg (qst, args, 4, "GRAPH_HARMONIC") : 0;
  if (BOX_ELEMENTS (args) > 3 &&
      vgraph_direction_arg (bif_arg (qst, args, 3, "GRAPH_HARMONIC"), VGRAPH_DIRENC_TRAVERSAL, GRAPH_DIR_OUTGOING, &hdir))
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGHAR06",
	  "GRAPH_HARMONIC: direction must be 0 or 'out', 1 or 'in', 2 or 'both'");
      return NULL;
    }

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGHAR01", "GRAPH_HARMONIC: node argument is NULL");
      return NULL;
    }

  graph_node_id_t target_node = vgraph_node_to_id_ex (node_arg, qst);
  if (target_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGHAR02", "GRAPH_HARMONIC: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGHAR03",
	  "GRAPH_HARMONIC: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  size_t ws_size = graph_algo_harmonic_workspace_size (ctx.snapshot);
  ctx.workspace = vgraph_get_workspace (ws_size);
  if (!ctx.workspace)
    {
      cleanup_algo_context (&ctx);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, "VGHAR04",
	  "GRAPH_HARMONIC: workspace of %lu bytes exceeds [Graph] MaxWorkspace (%lu bytes)",
	  (unsigned long) ws_size, (unsigned long) vgraph_workspace_limit ());
      return NULL;
    }

  graph_closeness_params_t params = GRAPH_CLOSENESS_DEFAULT;
  params.harmonic = true;
  params.normalized = (h_normalized != 0);
  params.direction = hdir;

  double h = 0.0;
  gerr = graph_algo_closeness_single (ctx.snapshot, &params, NULL, ctx.workspace, target_node, &h);

  cleanup_algo_context (&ctx);

  if (gerr == GRAPH_ERR_NOT_FOUND)
    {
      return NEW_DB_NULL;	/* target is not in the resolved graph */
    }
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGHAR05",
	  "GRAPH_HARMONIC: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  return box_double (h);
}

/* ============================================================================
 * BIFs: GRAPH_HITS_HUB and GRAPH_HITS_AUTHORITY
 *
 * SQL: GRAPH_HITS_HUB(node_iri, [graph_iri], [predicate_iri],
 *                     [max_iter], [tolerance])
 *      GRAPH_HITS_AUTHORITY(...same...)
 * Returns: DOUBLE PRECISION
 *
 * Two readings of one power iteration:
 *
 *   hub(u)  = sum of auth(v) over u's outgoing neighbours
 *   auth(v) = sum of hub(u)  over v's incoming neighbours
 *
 * A good hub points at good authorities; a good authority is pointed at
 * by good hubs.  The two rankings genuinely differ -- a node can be the
 * best authority and among the worst hubs -- which is what distinguishes
 * HITS from the single-vector measures.
 *
 * Both names share one compute callback and one cache entry holding both
 * vectors, so selecting hub and authority in the same query iterates
 * once.  See vgraph_batch_hits_compute.
 * ============================================================================ */

static caddr_t
bif_graph_hits_half (caddr_t *qst, caddr_t *err_ret, state_slot_t **args,
    const char *name, const vgraph_whole_graph_algo_t *algo, const char *e1, const char *e2, const char *e3, const char *e5)
{
  caddr_t node_arg = bif_arg (qst, args, 0, name);

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, e1, "%s: node argument is NULL", name);
      return NULL;
    }

  graph_node_id_t target_node = vgraph_node_to_id_ex (node_arg, qst);
  if (target_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, e2, "%s: invalid node IRI", name);
      return NULL;
    }

  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, name) : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, name) : NULL;

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, e3,
	  "%s: failed to load graph: %s", name, vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* Power iteration is O(iter*E); the shared driver keeps the pair in
   * the snapshot result cache, so the second node -- and the other
   * half of the pair -- is free. */
  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, algo, &br);
  /* A vector that has not reached the tolerance within max_iter is
   * still the best estimate available, and reporting it is what lets
   * max_iter be used to cap the work deliberately.  Every other caller
   * of a power iteration in this file treats CONVERGENCE the same way. */
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_CONVERGENCE)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, e5, "%s: algorithm failed: %s", name, graph_error_string (gerr));
      return NULL;
    }

  double v = 0.0;
  bool found = vgraph_payload_double_at (&br, ctx.snapshot, target_node,
      algo->payload_half, &v);
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);

  if (!found)
    {
      return NEW_DB_NULL;
    }

  return box_double (v);
}

static caddr_t
bif_graph_hits_hub (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  return bif_graph_hits_half (qst, err_ret, args, "GRAPH_HITS_HUB",
      &vgraph_wg_hits_hub, "VGHUB01", "VGHUB02", "VGHUB03", "VGHUB05");
}

static caddr_t
bif_graph_hits_authority (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  return bif_graph_hits_half (qst, err_ret, args, "GRAPH_HITS_AUTHORITY",
      &vgraph_wg_hits_auth, "VGAUT01", "VGAUT02", "VGAUT03", "VGAUT05");
}

/* ============================================================================
 * BIF: GRAPH_JACCARD_BATCH
 *
 * SQL: GRAPH_JACCARD_BATCH(a_vector, b_vector, [graph_iri], [predicate_iri])
 * Returns: VECTOR of DOUBLE - one similarity per pair, a_vector[i] against
 *          b_vector[i]
 *
 * The arithmetic per pair is GRAPH_JACCARD_SIMILARITY's, on the same
 * outgoing neighbourhoods; what this saves is resolving the graph and
 * taking the snapshot reference once for the whole list instead of once
 * per pair.  The two vectors must be the same length -- pairing a short
 * list against a long one is a caller error, not a request to stop early.
 * ============================================================================ */

static caddr_t
bif_graph_jaccard_batch (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t a_arg = bif_array_arg (qst, args, 0, "GRAPH_JACCARD_BATCH");
  caddr_t b_arg = bif_array_arg (qst, args, 1, "GRAPH_JACCARD_BATCH");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_JACCARD_BATCH") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_JACCARD_BATCH") : NULL;
  int jmode = BOX_ELEMENTS (args) > 4 ? (int) bif_long_arg (qst, args, 4, "GRAPH_JACCARD_BATCH") : 0;
  uint64_t n, i;
  graph_node_id_t *a_ids, *b_ids;
  double *sims;
  caddr_t *res;
  algo_context_t ctx;
  graph_error_t gerr;

  if (jmode < 0 || jmode > GRAPH_JACCARD_MODE_MAX)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGJCB07",
	  "GRAPH_JACCARD_BATCH: mode must be in [0,%d], got %d", GRAPH_JACCARD_MODE_MAX, jmode);
      return NULL;
    }
  if (BOX_ELEMENTS (a_arg) != BOX_ELEMENTS (b_arg))
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGJCB01",
	  "GRAPH_JACCARD_BATCH: the two node vectors must be the same length, got %d and %d",
	  (int) BOX_ELEMENTS (a_arg), (int) BOX_ELEMENTS (b_arg));
      return NULL;
    }
  n = (uint64_t) BOX_ELEMENTS (a_arg);
  if (0 == n)
    return (caddr_t) dk_alloc_box (0, DV_ARRAY_OF_POINTER);

  /* Resolve every IRI before loading the graph, so a bad one costs
   * nothing but the parse. */
  a_ids = (graph_node_id_t *) dk_alloc ((size_t) n * sizeof (graph_node_id_t));
  b_ids = (graph_node_id_t *) dk_alloc ((size_t) n * sizeof (graph_node_id_t));
  sims = (double *) dk_alloc ((size_t) n * sizeof (double));
  if (!a_ids || !b_ids || !sims)
    {
      if (a_ids)
	dk_free (a_ids, (size_t) n * sizeof (graph_node_id_t));
      if (b_ids)
	dk_free (b_ids, (size_t) n * sizeof (graph_node_id_t));
      if (sims)
	dk_free (sims, (size_t) n * sizeof (double));
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, "VGJCB02",
	  "GRAPH_JACCARD_BATCH: out of memory for %lu pairs", (unsigned long) n);
      return NULL;
    }
  for (i = 0; i < n; i++)
    {
      caddr_t av = ((caddr_t *) a_arg)[i];
      caddr_t bv = ((caddr_t *) b_arg)[i];
      if (!av || DV_TYPE_OF (av) == DV_DB_NULL || !bv || DV_TYPE_OF (bv) == DV_DB_NULL)
	{
	  dk_free (a_ids, (size_t) n * sizeof (graph_node_id_t));
	  dk_free (b_ids, (size_t) n * sizeof (graph_node_id_t));
	  dk_free (sims, (size_t) n * sizeof (double));
	  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGJCB03",
	      "GRAPH_JACCARD_BATCH: node argument is NULL at position %lu", (unsigned long) i);
	  return NULL;
	}
      a_ids[i] = vgraph_node_to_id_ex (av, qst);
      b_ids[i] = vgraph_node_to_id_ex (bv, qst);
      if (a_ids[i] == GRAPH_NODE_ID_INVALID || b_ids[i] == GRAPH_NODE_ID_INVALID)
	{
	  dk_free (a_ids, (size_t) n * sizeof (graph_node_id_t));
	  dk_free (b_ids, (size_t) n * sizeof (graph_node_id_t));
	  dk_free (sims, (size_t) n * sizeof (double));
	  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGJCB04",
	      "GRAPH_JACCARD_BATCH: invalid node IRI at position %lu", (unsigned long) i);
	  return NULL;
	}
    }

  gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      dk_free (a_ids, (size_t) n * sizeof (graph_node_id_t));
      dk_free (b_ids, (size_t) n * sizeof (graph_node_id_t));
      dk_free (sims, (size_t) n * sizeof (double));
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGJCB05",
	  "GRAPH_JACCARD_BATCH: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  gerr = graph_algo_jaccard_batch (ctx.snapshot, a_ids, b_ids, n, GRAPH_DIR_OUTGOING, NULL, (graph_jaccard_mode_t) jmode, sims);
  cleanup_algo_context (&ctx);
  dk_free (a_ids, (size_t) n * sizeof (graph_node_id_t));
  dk_free (b_ids, (size_t) n * sizeof (graph_node_id_t));

  if (gerr != GRAPH_OK)
    {
      dk_free (sims, (size_t) n * sizeof (double));
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGJCB06",
	  "GRAPH_JACCARD_BATCH: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  res = (caddr_t *) dk_alloc_box ((size_t) n * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (i = 0; i < n; i++)
    res[i] = box_double (sims[i]);
  dk_free (sims, (size_t) n * sizeof (double));
  return (caddr_t) res;
}

/* ============================================================================
 * BIF: GRAPH_SHORTEST_PATH_LENGTH
 * 
 * SQL: GRAPH_SHORTEST_PATH_LENGTH(from_node, to_node, [graph_iri], [predicate_iri])
 * Returns: INTEGER - length of shortest path, or NULL if no path exists
 * ============================================================================ */

static caddr_t
bif_graph_shortest_path_length (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t from_arg = bif_arg (qst, args, 0, "GRAPH_SHORTEST_PATH_LENGTH");
  caddr_t to_arg = bif_arg (qst, args, 1, "GRAPH_SHORTEST_PATH_LENGTH");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_SHORTEST_PATH_LENGTH") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_SHORTEST_PATH_LENGTH") : NULL;

  if (!from_arg || DV_TYPE_OF (from_arg) == DV_DB_NULL || !to_arg || DV_TYPE_OF (to_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGSP01", "GRAPH_SHORTEST_PATH_LENGTH: node argument is NULL");
      return NULL;
    }

  graph_node_id_t from_node = vgraph_node_to_id_ex (from_arg, qst);
  graph_node_id_t to_node = vgraph_node_to_id_ex (to_arg, qst);

  if (from_node == GRAPH_NODE_ID_INVALID || to_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGSP02", "GRAPH_SHORTEST_PATH_LENGTH: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGSP03",
	  "GRAPH_SHORTEST_PATH_LENGTH: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* One BFS per (snapshot, source) serves every target: the source is
   * part of the result-cache key and the target is an index into the
   * cached distance vector.  A query with one source and many targets
   * used to re-run the whole traversal per row. */
  ctx.src_node = from_node;

  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_spl, &br);
  if (gerr != GRAPH_OK)
    {
      bool no_ws = (GRAPH_ERR_OUT_OF_MEMORY == gerr && !ctx.workspace);
      size_t need = no_ws ? graph_algo_bfs_workspace_size (ctx.snapshot) : 0;
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	{
	  if (no_ws)
	    vgraph_workspace_error (err_ret, "GRAPH_SHORTEST_PATH_LENGTH", "VGSP04", need);
	  else
	    *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGSP05",
		"GRAPH_SHORTEST_PATH_LENGTH: algorithm failed: %s", graph_error_string (gerr));
	}
      return NULL;
    }

  int64_t dist = -1;
  uint64_t d = 0;
  if (vgraph_payload_int (&br, ctx.snapshot, to_node, &d) && d != UINT64_MAX)
    dist = (int64_t) d;

  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);
  return box_num (dist);
}

/* ============================================================================
 * BIF: GRAPH_JACCARD_SIMILARITY
 * 
 * SQL: GRAPH_JACCARD_SIMILARITY(node1, node2, [graph_iri], [predicate_iri])
 * Returns: DOUBLE PRECISION - Jaccard similarity [0, 1]
 * ============================================================================ */

static caddr_t
bif_graph_jaccard_similarity (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node1_arg = bif_arg (qst, args, 0, "GRAPH_JACCARD_SIMILARITY");
  caddr_t node2_arg = bif_arg (qst, args, 1, "GRAPH_JACCARD_SIMILARITY");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_JACCARD_SIMILARITY") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_JACCARD_SIMILARITY") : NULL;
  /* What the two nodes are compared by.  0 -- outgoing neighbours with the
   * predicate discarded -- is the default because it is what every caller
   * had before, and it is the reading Neo4j's gds.nodeSimilarity computes. */
  int jmode = BOX_ELEMENTS (args) > 4 ? (int) bif_long_arg (qst, args, 4, "GRAPH_JACCARD_SIMILARITY") : 0;
  if (jmode < 0 || jmode > GRAPH_JACCARD_MODE_MAX)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGJAC05",
	  "GRAPH_JACCARD_SIMILARITY: mode must be 0 (outgoing neighbours), "
	  "1 (outgoing predicate/object pairs), 2 (those and incoming), or " "3 (neighbours either way), got %d", jmode);
      return NULL;
    }

  if (!node1_arg || DV_TYPE_OF (node1_arg) == DV_DB_NULL || !node2_arg || DV_TYPE_OF (node2_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGJAC01", "GRAPH_JACCARD_SIMILARITY: node argument is NULL");
      return NULL;
    }

  graph_node_id_t node1 = vgraph_node_to_id_ex (node1_arg, qst);
  graph_node_id_t node2 = vgraph_node_to_id_ex (node2_arg, qst);

  if (node1 == GRAPH_NODE_ID_INVALID || node2 == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGJAC02", "GRAPH_JACCARD_SIMILARITY: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGJAC03",
	  "GRAPH_JACCARD_SIMILARITY: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  graph_jaccard_result_t result;
  gerr = graph_algo_jaccard (ctx.snapshot, node1, node2, GRAPH_DIR_OUTGOING, NULL, (graph_jaccard_mode_t) jmode, &result);

  if (gerr != GRAPH_OK)
    {
      cleanup_algo_context (&ctx);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGJAC04",
	  "GRAPH_JACCARD_SIMILARITY: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  double sim = result.similarity;
  cleanup_algo_context (&ctx);
  return box_double (sim);
}

/* ============================================================================
 * BIF: GRAPH_COMMUNITY_ID
 * 
 * SQL: GRAPH_COMMUNITY_ID(node_iri, [graph_iri], [predicate_iri])
 * Returns: INTEGER - community ID from Louvain algorithm
 * ============================================================================ */

static caddr_t
bif_graph_community_id (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_COMMUNITY_ID");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_COMMUNITY_ID") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_COMMUNITY_ID") : NULL;
  /* Optional resolution (default 1.0) */
  graph_louvain_params_t louvain_params = GRAPH_LOUVAIN_DEFAULT;
  if (BOX_ELEMENTS (args) > 3)
    {
      caddr_t a = bif_arg (qst, args, 3, "GRAPH_COMMUNITY_ID");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  louvain_params.resolution = vgraph_box_to_double (a);
	  if (louvain_params.resolution <= 0.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGCOM06",
		  "GRAPH_COMMUNITY_ID: resolution must be > 0, got %g", louvain_params.resolution);
	      return NULL;
	    }
	}
    }

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGCOM01", "GRAPH_COMMUNITY_ID: node argument is NULL");
      return NULL;
    }

  graph_node_id_t target_node = vgraph_node_to_id_ex (node_arg, qst);
  if (target_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGCOM02", "GRAPH_COMMUNITY_ID: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGCOM03",
	  "GRAPH_COMMUNITY_ID: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* Shared whole-graph driver; the partition is cached per resolution.
   * (void)louvain_params: the compute callback re-reads the same
   * argument, validated above. */
  (void) louvain_params;
  vgraph_batch_result_t br;
  uint64_t community_value = 0;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_community_id, &br);
  if (gerr != GRAPH_OK)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGCOM05",
	    "GRAPH_COMMUNITY_ID: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  long community_id = -1;
  bool found = vgraph_payload_int (&br, ctx.snapshot, target_node, &community_value);
  if (found)
    community_id = (long) community_value;
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);

  if (!found)
    {
      return NEW_DB_NULL;
    }

  return box_num (community_id);
}

/* ============================================================================
 * BIF: GRAPH_LABEL_PROPAGATION  (CDLP)
 *
 * SQL: GRAPH_LABEL_PROPAGATION(node_iri, [graph_iri], [predicate_iri], [max_iter])
 * Returns: INTEGER - community label, or NULL when the node is not in the graph
 *
 * This is not GRAPH_COMMUNITY_ID.  That one is Louvain, which optimises
 * modularity and produces a different partition; this one is the
 * deterministic label propagation, which is what another engine's CDLP
 * has to be compared against.
 * ============================================================================ */

static caddr_t
bif_graph_label_propagation (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_LABEL_PROPAGATION");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_LABEL_PROPAGATION") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_LABEL_PROPAGATION") : NULL;

  /* Validate the optional max_iter here as well as in the compute
   * callback, so a bad value is refused before the graph is loaded. */
  if (BOX_ELEMENTS (args) > 3)
    {
      caddr_t a = bif_arg (qst, args, 3, "GRAPH_LABEL_PROPAGATION");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  int64_t mi = unbox (a);
	  if (mi < 1 || mi > 100000)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLPA06",
		  "GRAPH_LABEL_PROPAGATION: max_iter must be in [1,100000], got %ld", (long) mi);
	      return NULL;
	    }
	}
    }
  /* label_form 1 reports the community's representative vertex as an
   * IRI_ID-valued integer; id_to_iri(iri_id_from_num(...)) names it. */
  if (BOX_ELEMENTS (args) > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_LABEL_PROPAGATION");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  int64_t lf = unbox (a);
	  if (lf < 0 || lf > 1)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLPA07",
		  "GRAPH_LABEL_PROPAGATION: label_form must be 0 (dense) or 1 (representative vertex), got %ld", (long) lf);
	      return NULL;
	    }
	}
    }

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGLPA01", "GRAPH_LABEL_PROPAGATION: node argument is NULL");
      return NULL;
    }

  graph_node_id_t target_node = vgraph_node_to_id_ex (node_arg, qst);
  if (target_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLPA02", "GRAPH_LABEL_PROPAGATION: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGLPA03",
	  "GRAPH_LABEL_PROPAGATION: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  vgraph_batch_result_t br;
  uint64_t label_value = 0;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_labelprop, &br);
  if (gerr != GRAPH_OK)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLPA05",
	    "GRAPH_LABEL_PROPAGATION: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  bool found = vgraph_payload_int (&br, ctx.snapshot, target_node, &label_value);
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);
  if (!found)
    return NEW_DB_NULL;
  return box_num ((long) label_value);
}

/* Which of the two forms a dual-form BIF was called in.
 *
 * GRAPH_TRIANGLE_COUNT and GRAPH_CLUSTERING_COEFFICIENT each answer either
 * about a whole graph -- `(graph [, pred ...])` -- or about one node of it
 * -- `(node, graph [, pred ...])`.  Nothing in the argument types
 * separates them: a graph is named by an IRI and so, usually, is a node.
 *
 * The rule here is the one the shapes imply, and it is the rule the old
 * comment claimed: it is the node form when the *second* argument names a
 * graph that loads AND the first argument is a node of that graph.  Both
 * halves are needed.  Without the second half, a global call whose
 * predicate IRI happened to name a graph as well would be read as a node
 * call; without the first, nothing rules out reading a global call's
 * predicate as the graph.
 *
 * What it replaces decided the question by which load happened to fail:
 * try arg0 as the graph, and if that did not resolve, shift everything
 * along.  That works only because an empty graph fails to load -- and the
 * default graph is the one exception, since the store always has it.  So a
 * node whose id is GRAPH_IRI_ID_DEFAULT, which is 1, resolved as "the
 * default graph" and the call answered the *global* form over an empty
 * graph: zero, silently, for a node with a perfectly good answer.
 *
 * That was unreachable while a graph's node ids were always IRI_IDs,
 * because Virtuoso never hands 1 to a user IRI -- 1 is rdf:type.  It
 * became reachable the moment a graph could be loaded from a SQL table,
 * where the node ids are whatever is in the column.  Measured on a
 * ten-vertex graph loaded from a table: vertex 1's directed clustering
 * coefficient came back 0 where it is 2/3, and every other vertex was
 * right.
 *
 * `arg0_node` is arg0 already resolved as a node id, resolved by the
 * caller and passed in rather than resolved here.  That is not tidiness:
 * vgraph_node_to_id_ex() consumes one entry of the vectored batch
 * resolution per call, so asking it twice for the same argument in one row
 * gets the second answer from somewhere else.
 *
 * On GRAPH_OK, *out_node_arg is arg0 for the node form and NULL for the
 * global one, and *out_pred_arg is whichever argument is the predicate. */
static graph_error_t
vgraph_dual_form_setup (caddr_t *qst, int nargs, caddr_t arg0, caddr_t arg1,
    caddr_t arg2, graph_node_id_t arg0_node, algo_context_t *ctx, caddr_t *out_node_arg, caddr_t *out_pred_arg)
{
  *out_node_arg = NULL;
  *out_pred_arg = arg1;

  if (nargs >= 2 && arg1 && DV_TYPE_OF (arg1) != DV_DB_NULL && GRAPH_NODE_ID_INVALID != arg0_node)
    {
      if (GRAPH_OK == setup_algo_context (qst, arg1, arg2, ctx))
	{
	  if (ctx->snapshot && UINT64_MAX != graph_snapshot_find_node (ctx->snapshot, arg0_node))
	    {
	      *out_node_arg = arg0;
	      *out_pred_arg = arg2;
	      return GRAPH_OK;
	    }
	  /* arg1 loaded but arg0 is not in it, so this is the global
	   * form over arg0 after all.  Release before trying again:
	   * setup_algo_context() freezes the worker count and may hold a
	   * cache reference. */
	  cleanup_algo_context (ctx);
	}
    }
  return setup_algo_context (qst, arg0, arg1, ctx);
}

/* ============================================================================
 * BIF: GRAPH_CLUSTERING_COEFFICIENT  (LCC)
 *
 * SQL: GRAPH_CLUSTERING_COEFFICIENT([graph_iri], [predicate_iri])
 *      GRAPH_CLUSTERING_COEFFICIENT(node_iri, [graph_iri], [predicate_iri])
 * Returns: DOUBLE PRECISION - the node's local clustering coefficient, or
 *          the graph-wide mean when no node is given.
 *
 * The per-node value is triangles(n) / (d*(d-1)/2) with d the undirected
 * degree, so it agrees by construction with GRAPH_TRIANGLE_COUNT(n, g) and
 * GRAPH_DEGREE_CENTRALITY(n, g) - which callers approximating this
 * themselves from those two BIFs had to get right, and from two separate
 * snapshots.
 * ============================================================================ */

static caddr_t
bif_graph_clustering_coefficient (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  int nargs = BOX_ELEMENTS (args);
  caddr_t arg0 = nargs > 0 ? bif_arg (qst, args, 0, "GRAPH_CLUSTERING_COEFFICIENT") : NULL;
  caddr_t arg1 = nargs > 1 ? bif_arg (qst, args, 1, "GRAPH_CLUSTERING_COEFFICIENT") : NULL;
  caddr_t arg2 = nargs > 2 ? bif_arg (qst, args, 2, "GRAPH_CLUSTERING_COEFFICIENT") : NULL;

  /* Same dual-form dispatch as GRAPH_TRIANGLE_COUNT; see
   * vgraph_dual_form_setup().  arg0 is resolved as a node exactly once,
   * here, because the vectored path hands out one pre-resolved id per
   * call. */
  caddr_t node_arg = NULL;
  caddr_t pred_arg = arg1;
  graph_node_id_t arg0_node = vgraph_node_to_id_ex (arg0, qst);

  algo_context_t ctx;
  graph_error_t gerr = vgraph_dual_form_setup (qst, nargs, arg0, arg1, arg2,
      arg0_node, &ctx,
      &node_arg, &pred_arg);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGLCC01",
	  "GRAPH_CLUSTERING_COEFFICIENT: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_clustering, &br);
  if (gerr != GRAPH_OK)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLCC03",
	    "GRAPH_CLUSTERING_COEFFICIENT: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  if (node_arg)
    {
      double coef = 0.0;
      /* arg0_node, not a second resolution: the dispatch above already
       * established it is a node of this graph. */
      bool found = vgraph_payload_double (&br, ctx.snapshot, arg0_node, &coef);
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!found)
	return NEW_DB_NULL;
      return box_double (coef);
    }

  /* Global form: the mean over every node, counting the degree < 2 nodes
   * as the zeroes they are.  Computed from the payload rather than from
   * the result struct, so a cache hit serves it - the same treatment
   * bif_graph_triangle_count gives its global total. */
  {
    const double *coefs = (const double *) br.payload;
    double sum = 0.0;
    uint64_t i;
    for (i = 0; coefs && i < br.node_count; i++)
      sum += coefs[i];
    double avg = br.node_count ? sum / (double) br.node_count : 0.0;
    vgraph_payload_release (&br);
    cleanup_algo_context (&ctx);
    return box_double (avg);
  }
}

/* ============================================================================
 * BIF: GRAPH_TRIANGLE_COUNT
 *
 * SQL: GRAPH_TRIANGLE_COUNT([graph_iri], [predicate_iri])
 *      GRAPH_TRIANGLE_COUNT(node_iri, [graph_iri], [predicate_iri])
 * Returns: INTEGER - total number of triangles, or per-node count if node given
 * ============================================================================ */

static caddr_t
bif_graph_triangle_count (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  int nargs = BOX_ELEMENTS (args);
  caddr_t arg0 = nargs > 0 ? bif_arg (qst, args, 0, "GRAPH_TRIANGLE_COUNT") : NULL;
  caddr_t arg1 = nargs > 1 ? bif_arg (qst, args, 1, "GRAPH_TRIANGLE_COUNT") : NULL;
  caddr_t arg2 = nargs > 2 ? bif_arg (qst, args, 2, "GRAPH_TRIANGLE_COUNT") : NULL;

  /* The per-node form (node, graph, [pred]) or the global form
   * (graph, [pred])?  The predicate-position compiler sends the first,
   * the BIND/SQL form the second, and vgraph_dual_form_setup() decides
   * which -- by whether arg1 names a graph that holds arg0, rather than
   * by which load fails first. */
  caddr_t node_arg = NULL;
  caddr_t pred_arg = arg1;
  graph_node_id_t arg0_node = vgraph_node_to_id_ex (arg0, qst);

  algo_context_t ctx;
  graph_error_t gerr = vgraph_dual_form_setup (qst, nargs, arg0, arg1, arg2,
      arg0_node, &ctx,
      &node_arg, &pred_arg);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGTRI01",
	  "GRAPH_TRIANGLE_COUNT: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_triangles, &br);
  if (gerr != GRAPH_OK)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGTRI03",
	    "GRAPH_TRIANGLE_COUNT: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  /* If a node argument was provided, return the per-node triangle count.
   * Otherwise return the global total. */
  long count;
  if (node_arg)
    {
      uint64_t tri_value = 0;
      bool found = vgraph_payload_int (&br, ctx.snapshot, arg0_node, &tri_value);
      count = (long) tri_value;
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!found)
	return NEW_DB_NULL;
      return box_num (count);
    }

  /* Global form: every triangle contributed three per-node increments,
   * so the total is the sum over the same payload divided by three -
   * exactly what graph_algo_triangles() reports, and available from a
   * cached payload without re-running the count. */
  {
    uint64_t total = 0, i;
    const uint64_t *tri = (const uint64_t *) br.payload;
    for (i = 0; tri && i < br.node_count; i++)
      total += tri[i];
    count = (long) (total / 3);
  }
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);
  return box_num (count);
}

/* ============================================================================
 * BIF: GRAPH_EIGENVECTOR_CENTRALITY
 * 
 * SQL: GRAPH_EIGENVECTOR_CENTRALITY(node_iri, [graph_iri], [predicate_iri])
 * Returns: DOUBLE PRECISION - eigenvector centrality score
 * ============================================================================ */

static caddr_t
bif_graph_eigenvector_centrality (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_EIGENVECTOR_CENTRALITY");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_EIGENVECTOR_CENTRALITY") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_EIGENVECTOR_CENTRALITY") : NULL;
  /* Optional: max_iter (default 100), tolerance (default 1e-6) */
  graph_eigenvector_params_t params = GRAPH_EIGENVECTOR_DEFAULT;
  if (BOX_ELEMENTS (args) > 3)
    {
      caddr_t a = bif_arg (qst, args, 3, "GRAPH_EIGENVECTOR_CENTRALITY");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  /* Accept any numeric box type (SPARQL emits DV_LONG_INT but
	   * SQL callers may pass other numeric types). */
	  double mi_d = vgraph_box_to_double (a);
	  int64_t mi = (int64_t) mi_d;
	  if (mi_d != (double) mi || mi < 1 || mi > 100000)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGEIG06",
		  "GRAPH_EIGENVECTOR_CENTRALITY: max_iter must be an integer in [1,100000], got %g", mi_d);
	      return NULL;
	    }
	  params.max_iterations = (int) mi;
	}
    }
  if (BOX_ELEMENTS (args) > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_EIGENVECTOR_CENTRALITY");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  params.epsilon = vgraph_box_to_double (a);
	  if (params.epsilon <= 0.0 || params.epsilon >= 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGEIG07",
		  "GRAPH_EIGENVECTOR_CENTRALITY: tolerance must be in (0,1), got %g", params.epsilon);
	      return NULL;
	    }
	}
    }

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGEIG01", "GRAPH_EIGENVECTOR_CENTRALITY: node argument is NULL");
      return NULL;
    }

  graph_node_id_t target_node = vgraph_node_to_id_ex (node_arg, qst);
  if (target_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGEIG02", "GRAPH_EIGENVECTOR_CENTRALITY: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGEIG03",
	  "GRAPH_EIGENVECTOR_CENTRALITY: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* Shared whole-graph driver: the score vector comes from the result
   * cache when this snapshot has already been solved with the same
   * max_iter/tolerance.  (void)params: the compute callback re-reads the
   * same arguments, validated above. */
  (void) params;
  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_eigenvector, &br);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_CONVERGENCE)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGEIG05",
	    "GRAPH_EIGENVECTOR_CENTRALITY: algorithm failed: %s", graph_error_string (gerr));
      return NULL;
    }

  double eig = 0.0;
  bool found = vgraph_payload_double (&br, ctx.snapshot, target_node, &eig);
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);

  if (!found)
    {
      return NEW_DB_NULL;
    }

  return box_double (eig);
}

/* ============================================================================
 * BIF: GRAPH_SHORTEST_PATH
 * 
 * SQL: GRAPH_SHORTEST_PATH(from_node, to_node, [graph_iri], [predicate_iri], [return_type])
 * Returns: ARRAY - path information as vector:
 *   Default (return_type=0 or NULL): vector of node IRIs in path
 *   return_type=1: vector(nodeNames, costs, totalCost) Neo4j-style
 * ============================================================================ */

static caddr_t
bif_graph_shortest_path (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t from_arg = bif_arg (qst, args, 0, "GRAPH_SHORTEST_PATH");
  caddr_t to_arg = bif_arg (qst, args, 1, "GRAPH_SHORTEST_PATH");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_SHORTEST_PATH") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_SHORTEST_PATH") : NULL;
  caddr_t return_type_arg = BOX_ELEMENTS (args) > 4 ? bif_arg (qst, args, 4, "GRAPH_SHORTEST_PATH") : NULL;

  int return_type = 0;
  if (return_type_arg && DV_TYPE_OF (return_type_arg) != DV_DB_NULL)
    {
      return_type = (int) unbox (return_type_arg);
    }

  if (!from_arg || DV_TYPE_OF (from_arg) == DV_DB_NULL || !to_arg || DV_TYPE_OF (to_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGPATH01", "GRAPH_SHORTEST_PATH: node argument is NULL");
      return NULL;
    }

  graph_node_id_t from_node = vgraph_node_to_id_ex (from_arg, qst);
  graph_node_id_t to_node = vgraph_node_to_id_ex (to_arg, qst);

  if (from_node == GRAPH_NODE_ID_INVALID || to_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPATH02", "GRAPH_SHORTEST_PATH: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGPATH03",
	  "GRAPH_SHORTEST_PATH: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* The path form needs the parent vector as well as the distances, so
   * the cached payload carries both: {distances[V], parents[V]} from one
   * BFS per (snapshot, source).  It shares that entry with
   * GRAPH_SHORTEST_PATH_LENGTH and with GRAPH_BFS at direction 0. */
  ctx.src_node = from_node;

  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_sp, &br);
  if (gerr != GRAPH_OK)
    {
      bool no_ws = (GRAPH_ERR_OUT_OF_MEMORY == gerr && !ctx.workspace);
      size_t need = no_ws ? graph_algo_bfs_workspace_size (ctx.snapshot) : 0;
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	{
	  if (no_ws)
	    vgraph_workspace_error (err_ret, "GRAPH_SHORTEST_PATH", "VGPATH04", need);
	  else
	    *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGPATH05",
		"GRAPH_SHORTEST_PATH: algorithm failed: %s", graph_error_string (gerr));
	}
      return NULL;
    }

  const uint64_t *distances = (const uint64_t *) br.payload;
  const graph_node_id_t *parents = vgraph_payload_parents (&br);
  uint64_t to_idx = find_node_index (ctx.snapshot, to_node);
  if (!distances || !parents || UINT64_MAX == to_idx || to_idx >= br.node_count || UINT64_MAX == distances[to_idx])
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      return NEW_DB_NULL;	/* No path exists */
    }

  uint64_t dist = distances[to_idx];
  uint64_t path_len = dist + 1;
  size_t path_nodes_size = path_len * sizeof (graph_node_id_t);
  graph_node_id_t *path_nodes = (graph_node_id_t *) dk_alloc (path_nodes_size);
  if (!path_nodes)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, "VGPATH06", "GRAPH_SHORTEST_PATH: path allocation failed");
      return NULL;
    }

  /* Walk the parents back from the target.  parents[] holds node ids
   * indexed by snapshot node index, so this is a hash lookup per hop
   * rather than the linear node-map scan this used to do. */
  {
    uint64_t k = path_len;
    graph_node_id_t current = to_node;
    bool complete = false;
    while (k > 0)
      {
	uint64_t idx;
	path_nodes[--k] = current;
	if (current == from_node)
	  {
	    complete = (0 == k);
	    break;
	  }
	idx = find_node_index (ctx.snapshot, current);
	if (UINT64_MAX == idx || idx >= br.node_count)
	  break;
	current = parents[idx];
	if (GRAPH_NODE_ID_INVALID == current)
	  break;
      }
    if (!complete)
      {
	dk_free (path_nodes, path_nodes_size);
	vgraph_payload_release (&br);
	cleanup_algo_context (&ctx);
	return NEW_DB_NULL;
      }
  }

  caddr_t ret_val;

  if (return_type == 1)
    {
      /* Neo4j-style: vector(nodeNames, costs, totalCost) */
      caddr_t *node_names = (caddr_t *) dk_alloc_box (path_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      caddr_t *costs = (caddr_t *) dk_alloc_box (path_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

      for (uint64_t i = 0; i < path_len; i++)
	{
	  caddr_t iri = vgraph_id_to_iri_ex (path_nodes[i], qst);
	  node_names[i] = iri ? iri : NEW_DB_NULL;
	  costs[i] = box_double ((double) i);	/* Unweighted: cost = hop count */
	}

      caddr_t *result_arr = (caddr_t *) dk_alloc_box (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      result_arr[0] = (caddr_t) node_names;
      result_arr[1] = (caddr_t) costs;
      result_arr[2] = box_double ((double) dist);
      ret_val = (caddr_t) result_arr;
    }
  else
    {
      /* Default: simple vector of node IRIs */
      caddr_t *path_iris = (caddr_t *) dk_alloc_box (path_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (uint64_t i = 0; i < path_len; i++)
	{
	  caddr_t iri = vgraph_id_to_iri_ex (path_nodes[i], qst);
	  path_iris[i] = iri ? iri : NEW_DB_NULL;
	}
      ret_val = (caddr_t) path_iris;
    }

  dk_free (path_nodes, path_nodes_size);
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);
  return ret_val;
}

/* ============================================================================
 * WEIGHTED GRAPH SUPPORT
 *
 * Weight lookup table for RDF reification pattern weights.
 *
 * Two RDF weight patterns are supported:
 *
 * 1. W3C reification (rdf:subject / rdf:predicate / rdf:object):
 *    _:r rdf:subject :alice ;
 *       rdf:predicate :follows ;
 *       rdf:object :bob ;
 *       :weight 0.9 .
 *
 * 2. RDF 1.2 triple terms (<< >> syntax, stored as reification internally):
 *    << :alice :follows :bob >> :weight 0.9 .
 *
 * The BIF accepts a weight_predicate_iri argument (e.g. iri_to_id(':weight'))
 * and automatically scans the graph for reified statements matching either
 * of these patterns, building the weight lookup table.
 * ============================================================================ */

/* Order the weight table by (subject, object) so that
 * weighted_edge_lookup() can bisect it.  Called once per build; every
 * relaxation in Dijkstra then costs O(log W) instead of O(W).  Comparing
 * through a signed subtraction would overflow on IRI_IDs, hence the
 * explicit ordering. */
static int
weight_entry_cmp (const void *a, const void *b)
{
  const weight_entry_t *ea = (const weight_entry_t *) a;
  const weight_entry_t *eb = (const weight_entry_t *) b;
  if (ea->subject < eb->subject)
    return -1;
  if (ea->subject > eb->subject)
    return 1;
  if (ea->object < eb->object)
    return -1;
  if (ea->object > eb->object)
    return 1;
  return 0;
}

/* How long the last weight-table build spent reading the weights out of
 * RDF, and how long sorting them.  The two were only ever visible as one
 * 113-second number, and which half it was had to be inferred by
 * subtracting SQL timings taken separately -- which is a guess dressed as
 * a measurement.  Reported by GRAPH_CACHE_STATUS. */
static uint32_t s_wl_scan_ms = 0;
static uint32_t s_wl_sort_ms = 0;
/* Entries in the last weight table, and whether building it ran out of
 * memory part way.
 *
 * The growth failure was a bare `break`: the scan stopped, the table kept
 * whatever it had, and every edge past that point silently took the
 * default weight of 1.0.  Shortest paths then come back *shorter* than
 * they really are, with no error anywhere -- which is the worst way for a
 * database to be wrong.  Both are reported by GRAPH_CACHE_STATUS, and the
 * truncation is logged. */
static uint64_t s_wl_entries = 0;
static uint32_t s_wl_truncated = 0;

static void
sort_weight_lookup (weight_lookup_t *lookup)
{
  uint32_t t0;
  if (!lookup || !lookup->entries || lookup->sorted)
    return;
  t0 = get_msec_real_time ();
  if (lookup->count > 1)
    qsort (lookup->entries, (size_t) lookup->count, sizeof (weight_entry_t), weight_entry_cmp);
  s_wl_sort_ms = get_msec_real_time () - t0;
  lookup->sorted = true;
}

static void weight_cache_unref (void *shared);

static void
free_weight_lookup (weight_lookup_t *lookup)
{
  if (lookup && lookup->shared)
    {
      weight_cache_unref (lookup->shared);
      lookup->shared = NULL;
      lookup->entries = NULL;
      lookup->count = 0;
      lookup->capacity = 0;
      lookup->sorted = false;
      lookup->symmetric = false;
      return;
    }
  if (lookup && lookup->entries)
    {
      dk_free (lookup->entries, lookup->capacity * sizeof (weight_entry_t));
      lookup->entries = NULL;
      lookup->count = 0;
      lookup->capacity = 0;
      lookup->sorted = false;
    }
}

/* One directed probe of the table.  Returns false when the pair is absent,
 * which is what lets the symmetric retry below tell a miss from a weight
 * that happens to equal the default. */
static bool
weight_entry_find (const weight_lookup_t *lookup, graph_node_id_t subject, graph_node_id_t object, double *out)
{
  if (lookup->sorted)
    {
      /* Bisect on (subject, object).  Dijkstra relaxes every edge, so this
       * is the difference between O(E log W) and O(E * W). */
      uint64_t lo = 0, hi = lookup->count;
      while (lo < hi)
	{
	  uint64_t mid = lo + (hi - lo) / 2;
	  const weight_entry_t *e = &lookup->entries[mid];
	  if (e->subject < subject || (e->subject == subject && e->object < object))
	    lo = mid + 1;
	  else if (e->subject == subject && e->object == object)
	    {
	      *out = e->weight;
	      return true;
	    }
	  else
	    hi = mid;
	}
      return false;
    }
  for (uint64_t i = 0; i < lookup->count; i++)
    {
      if (lookup->entries[i].subject == subject && lookup->entries[i].object == object)
	{
	  *out = lookup->entries[i].weight;
	  return true;
	}
    }
  return false;
}

static double
weighted_edge_lookup (graph_node_id_t subject, graph_pred_id_t predicate, graph_node_id_t object, void *user_data)
{
  (void) predicate;
  weight_lookup_t *lookup = (weight_lookup_t *) user_data;
  double w;
  if (!lookup || !lookup->entries)
    return lookup ? lookup->default_weight : 1.0;

  if (weight_entry_find (lookup, subject, object, &w))
    return w;
  if (lookup->symmetric && weight_entry_find (lookup, object, subject, &w))
    return w;

  /* There used to be a second scan here that retried the match on the
   * low 32 bits of each id, labelled a workaround for "Virtuoso boxing
   * differences".  Both builders now resolve ids the same way the
   * traversal does, so it was dead: instrumented, it fired zero times
   * across the whole graph suite, Group J's weighted values included.
   * It is gone rather than indexed, because a lookup that silently
   * matches a different edge is worse than one that misses. */
  return lookup->default_weight;
}

/* Sum the weights of one node's incident edges.
 *
 * `direction` is the argument the two weighted-degree BIFs take: 0 both,
 * 1 incoming, 2 outgoing.  `positive_only` skips a non-positive weight,
 * which is what GRAPH_DEGREE_W_SPARQL does and GRAPH_DEGREE_WEIGHTED does
 * not.
 *
 * Walks the shared neighbour iterator rather than the base store's
 * adjacency records.  Both BIFs used to read graph_edge_t directly, and
 * for their incoming half both scanned *every node in the graph* looking
 * for edges that pointed at this one -- O(V*E) to answer what an inverse
 * CSR row answers in O(degree).  The records are also about to stop
 * existing on a snapshot whose edges all carry one predicate, and this
 * iterator is the one reader of them that does not care either way.
 *
 * The summation order is the order the old code used, which matters
 * because these values are pinned to the last digit: one pass per
 * direction, so it is base-out, delta-out, base-in, delta-in exactly as
 * before.  A self-loop counts once, on the outgoing pass only -- the old
 * incoming scan skipped a source equal to the node, and the inverse row
 * does not, so the skip is written out here instead. */
static double
vgraph_weighted_degree_sum (const graph_snapshot_t *snap, graph_node_id_t node,
    int direction, bool positive_only, weight_lookup_t *wl)
{
  double total = 0.0;
  uint64_t self_ix, nix;
  neighbor_ctx_t ctx;

  if (!snap)
    return 0.0;
  self_ix = graph_snapshot_find_node (snap, node);
  if (UINT64_MAX == self_ix)
    return 0.0;

  if (direction != 1)
    {
      neighbor_init_at (&ctx, snap, self_ix, GRAPH_DIR_OUTGOING, NULL);
      while (neighbor_next (&ctx, &nix))
	{
	  double w = weighted_edge_lookup (node, 0, neighbor_id (&ctx), wl);
	  if (!positive_only || w > 0)
	    total += w;
	}
    }
  if (direction != 2)
    {
      neighbor_init_at (&ctx, snap, self_ix, GRAPH_DIR_INCOMING, NULL);
      while (neighbor_next (&ctx, &nix))
	{
	  graph_node_id_t src = neighbor_id (&ctx);
	  double w;
	  if (src == node)
	    continue;		/* counted on the outgoing pass */
	  w = weighted_edge_lookup (src, 0, node, wl);
	  if (!positive_only || w > 0)
	    total += w;
	}
    }
  return total;
}

/* Convert a weight value box of any supported RDF type to double.
 *
 * *ok says whether it was a number at all.  Callers that must not invent
 * a weight pass it; the lenient wrapper below keeps the old behaviour of
 * falling back to 1.0 for the callers that always did. */
static double
weight_value_to_double_ok (caddr_t weight_box, bool *ok)
{
  int wtype;
  if (ok)
    *ok = true;
  /* A literal that came through SPARQL arrives wrapped.  Unwrapped it is
   * an ordinary number or string; left wrapped it matched nothing below
   * and weighed 1.0, so a weighted query answered with unweighted
   * numbers and said nothing about it. */
  /* No test for a null pointer anywhere here.  DV_TYPE_OF() calls
   * anything that is not a box pointer a DV_LONG_INT, and Virtuoso
   * boxes a small integer inline -- so the integer 0 and a C NULL are
   * the same pointer.  Rejecting "null" by testing the pointer rejects
   * a weight of zero, which is a number and a perfectly ordinary one:
   * it cost a live federated query, where one actor of 366 had no
   * sitelinks.  A real SQL NULL is a DV_DB_NULL box, which is a box
   * pointer and is caught by type below. */
  if (DV_RDF == DV_TYPE_OF (weight_box))
    {
      if (!((rdf_box_t *) weight_box)->rb_is_complete)
	{
	  if (ok)
	    *ok = false;
	  return 1.0;
	}
      weight_box = ((rdf_box_t *) weight_box)->rb_box;
    }
  wtype = DV_TYPE_OF (weight_box);
  if (DV_DB_NULL == wtype)
    {
      if (ok)
	*ok = false;
      return 1.0;
    }
  if (wtype == DV_DOUBLE_FLOAT || wtype == DV_DOUBLE_PREC)
    {
      return unbox_double (weight_box);
    }
  else if (wtype == DV_SINGLE_FLOAT)
    {
      return (double) unbox_float (weight_box);
    }
  else if (wtype == DV_LONG_INT || wtype == DV_SHORT_INT || wtype == DV_INT64)
    {
      return (double) unbox (weight_box);
    }
  else if (wtype == DV_NUMERIC)
    {
      double w = 1.0;
      numeric_to_double ((numeric_t) weight_box, &w);
      return w;
    }
  else if (wtype == DV_STRING || wtype == DV_SHORT_STRING || wtype == DV_LONG_STRING)
    {
      const char *t = (const char *) weight_box;
      char *end = NULL;
      double w;
      while (*t == ' ' || *t == '\t')
	t++;
      w = strtod (t, &end);
      /* "abc" is not a weight of zero; it is not a weight. */
      if (!end || end == t)
	{
	  if (ok)
	    *ok = false;
	  return 1.0;
	}
      while (*end == ' ' || *end == '\t')
	end++;
      if (*end)
	{
	  if (ok)
	    *ok = false;
	  return 1.0;
	}
      return w;
    }
  if (ok)
    *ok = false;
  return 1.0;
}

/* The lenient form the older callers use: anything unreadable weighs the
 * default, which is the answer they have always given. */
static double
weight_value_to_double (caddr_t weight_box)
{
  return weight_value_to_double_ok (weight_box, NULL);
}

/* Same coercion, under the name the table loader in bif_graph_scope.c
 * uses.  One implementation, two callers in different translation
 * units. */
double
vgraph_weight_box_to_double (caddr_t weight_box)
{
  return weight_value_to_double (weight_box);
}

/* IRI IDs for the standard reification vocabulary.
 * These are resolved once and cached. */
static graph_iri_id_t s_rdf_subject_iri = 0;	/* rdf:subject */
static graph_iri_id_t s_rdf_predicate_iri = 0;	/* rdf:predicate */
static graph_iri_id_t s_rdf_object_iri = 0;	/* rdf:object */
static graph_iri_id_t s_rdf_reifies_iri = 0;	/* rdf:reifies */

static void
ensure_reification_iris (caddr_t *qst)
{
  if (s_rdf_subject_iri && s_rdf_predicate_iri && s_rdf_object_iri && s_rdf_reifies_iri)
    return;
  caddr_t err = NULL;
  caddr_t id_box;
  id_box = iri_to_id (qst, box_dv_short_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#subject"), IRI_TO_ID_WITH_CREATE, &err);
  if (!err && id_box)
    {
      s_rdf_subject_iri = (graph_iri_id_t) unbox_iri_id (id_box);
      dk_free_tree (id_box);
    }
  if (err)
    {
      dk_free_tree (err);
      err = NULL;
    }
  id_box = iri_to_id (qst, box_dv_short_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate"),
      IRI_TO_ID_WITH_CREATE, &err);
  if (!err && id_box)
    {
      s_rdf_predicate_iri = (graph_iri_id_t) unbox_iri_id (id_box);
      dk_free_tree (id_box);
    }
  if (err)
    {
      dk_free_tree (err);
      err = NULL;
    }
  id_box = iri_to_id (qst, box_dv_short_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#object"), IRI_TO_ID_WITH_CREATE, &err);
  if (!err && id_box)
    {
      s_rdf_object_iri = (graph_iri_id_t) unbox_iri_id (id_box);
      dk_free_tree (id_box);
    }
  if (err)
    {
      dk_free_tree (err);
      err = NULL;
    }
  id_box = iri_to_id (qst, box_dv_short_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies"), IRI_TO_ID_WITH_CREATE, &err);
  if (!err && id_box)
    {
      s_rdf_reifies_iri = (graph_iri_id_t) unbox_iri_id (id_box);
      dk_free_tree (id_box);
    }
  if (err)
    {
      dk_free_tree (err);
      err = NULL;
    }
}

/* Expose the reification vocabulary IRI IDs to the quad loader
 * (bif_graph_scope.c) so that all-predicates loads can exclude them. */
void
vgraph_reification_vocab_ids (void *qst, graph_iri_id_t *subj, graph_iri_id_t *pred, graph_iri_id_t *obj, graph_iri_id_t *reifies)
{
  ensure_reification_iris ((caddr_t *) qst);
  *subj = s_rdf_subject_iri;
  *pred = s_rdf_predicate_iri;
  *obj = s_rdf_object_iri;
  *reifies = s_rdf_reifies_iri;
}

/* Build a weight lookup from RDF reification patterns in the graph.
 *
 * This scans the named graph for reified statements that have a
 * weight predicate. Two patterns are searched:
 *
 * 1. RDF 1.2 triple terms - the reifier IRI encodes the base triple:
 *    << s p o >> <weight_pred> ?w .
 *    stored as <urn:rdf-star:triple:S:P:iO> <weight_pred> ?w .
 *
 * 2. W3C reification (plain triples):
 *    ?stmt rdf:subject ?s ; rdf:predicate ?p ; rdf:object ?o ;
 *          <weight_pred> ?w .
 *
 * The weight predicate is the one passed by the user (e.g. :weight, :hasScore).
 *
 * Returns GRAPH_OK on success, error code on failure.
 */
/* Compile-once plan for the weight scan; freed at server shutdown like the
 * other static plans.  Guarded by the shared graph compile mutex. */
static query_t *g_weight_qr = NULL;
static query_t *g_reif_weight_qr = NULL;
static query_t *g_reifies_weight_qr = NULL;

/* Read the subject and object IRI IDs out of an RDF 1.2 reifier IRI:
 *   urn:rdf-star:reifier:<S>:<P>:i<O>
 *   urn:rdf-star:triple:<S>:<P>:i<O>
 * Returns false for anything else. */
static bool
parse_reifier_iri (caddr_t iri_box, graph_node_id_t *src_out, graph_node_id_t *obj_out)
{
  static const char reifier_prefix[] = "urn:rdf-star:reifier:";
  static const char triple_prefix[] = "urn:rdf-star:triple:";
  const size_t reifier_prefix_len = sizeof (reifier_prefix) - 1;
  const size_t triple_prefix_len = sizeof (triple_prefix) - 1;
  const char *s, *p;
  size_t slen, prefix_len = 0;
  char *endptr;
  unsigned long long s_iid, o_iid;
  int t = iri_box ? DV_TYPE_OF (iri_box) : 0;

  if (t != DV_STRING && t != DV_SHORT_STRING && t != DV_LONG_STRING && t != DV_UNAME)
    return false;
  s = (const char *) iri_box;
  slen = box_length (iri_box) - 1;
  if (slen > reifier_prefix_len && !strncmp (s, reifier_prefix, reifier_prefix_len))
    prefix_len = reifier_prefix_len;
  else if (slen > triple_prefix_len && !strncmp (s, triple_prefix, triple_prefix_len))
    prefix_len = triple_prefix_len;
  else
    return false;

  p = s + prefix_len;
  s_iid = strtoull (p, &endptr, 10);
  if (*endptr != ':')
    return false;
  p = endptr + 1;
  (void) strtoull (p, &endptr, 10);	/* the predicate id, unused */
  if (*endptr != ':')
    return false;
  p = endptr + 1;
  if (*p == 'i')
    p++;
  o_iid = strtoull (p, &endptr, 10);
  if (s_iid == 0 || o_iid == 0)
    return false;
  *src_out = (graph_node_id_t) s_iid;
  *obj_out = (graph_node_id_t) o_iid;
  return true;
}

/* Record that the table could not grow.  Called from all three scans. */
static void
wl_growth_failed (uint64_t sofar)
{
  s_wl_truncated = 1;
  log_error ("GRAPH: out of memory building the edge weight table after "
      BOXINT_FMT " weights.  Weighted traversals over this graph "
      "would give every remaining edge the default weight and so " "return distances that are too short.", (boxint) sofar);
}

/* Append one entry, growing the table.  Returns false when the table
 * cannot grow, which is the caller's signal to stop reading. */
static bool
weight_lookup_add (weight_lookup_t *lookup, graph_node_id_t subject, graph_node_id_t object, double weight)
{
  if (lookup->count >= lookup->capacity)
    {
      uint64_t new_cap = lookup->capacity ? lookup->capacity * 2 : 64;
      weight_entry_t *grown = (weight_entry_t *) dk_alloc (new_cap * sizeof (weight_entry_t));
      if (!grown)
	return false;
      if (lookup->entries)
	{
	  memcpy (grown, lookup->entries, lookup->count * sizeof (weight_entry_t));
	  dk_free (lookup->entries, lookup->capacity * sizeof (weight_entry_t));
	}
      lookup->entries = grown;
      lookup->capacity = new_cap;
    }
  lookup->entries[lookup->count].subject = subject;
  lookup->entries[lookup->count].object = object;
  lookup->entries[lookup->count].weight = weight;
  lookup->count++;
  return true;
}

/* Read one weight per edge out of a SQL table's column.
 *
 * This is the whole of why loading a graph from a table is worth doing.
 * The RDF form of a weighted edge is three triples -- the edge, a
 * blank-node reifier, and the weight on the reifier -- so reading the
 * weights back means materialising a 45-character reifier IRI from an id
 * with ID_TO_IRI and parsing the ids out of the string again, 34 million
 * times, and delivering three columns through a cursor to do it.  Measured
 * at 34,185,747 edges that scan is about 110 s, of which the SQL is 2.6 s
 * and the rest is the per-row work.  From a column there is no reifier, no
 * string and no parse: it is one scan of one table.
 *
 * Runs on the caller's own connection, so the caller's SELECT permission
 * on the table is the permission check -- the same argument
 * vgraph_load_from_table() makes for the edges, and the reason neither may
 * use bootstrap_cli.  The graph-level RDF check the RDF builder makes has
 * nothing to check here: a table-sourced graph is not in RDF_QUAD.
 *
 * The table and column names are validated by vgraph_table_name_ok()
 * before they reach the registry, and again here, because this text is
 * interpolated into SQL. */
static graph_error_t
build_weight_lookup_from_table_unsorted (caddr_t *qst, const char *table, const char *weight_col, weight_lookup_t *lookup)
{
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi ? qi->qi_client : NULL;
  caddr_t exec_err = NULL;
  query_t *qr = NULL;
  local_cursor_t *lc = NULL;
  graph_error_t result = GRAPH_OK;
  char sql[512];

  if (!qst || !lookup || !table || !weight_col || !weight_col[0])
    return GRAPH_ERR_NULL_PTR;
  if (!cli)
    return GRAPH_ERR_NOT_INITIALIZED;
  if (!vgraph_table_name_ok (table) || !vgraph_table_name_ok (weight_col))
    return GRAPH_ERR_INVALID_PARAM;
  if (strchr (weight_col, '.'))
    return GRAPH_ERR_INVALID_PARAM;

  snprintf (sql, sizeof (sql), "SELECT S, O, %s FROM %s", weight_col, table);

  qr = sql_compile (sql, cli, &exec_err, SQLC_DEFAULT);
  if (exec_err || !qr)
    {
      vgraph_load_error_set (exec_err);
      result = GRAPH_ERR_IO_ERROR;
      goto cleanup;
    }

  exec_err = qr_rec_exec (qr, cli, &lc, qi, NULL, 0);
  if (exec_err)
    {
      vgraph_load_error_set (exec_err);
      result = GRAPH_ERR_IO_ERROR;
      goto cleanup;
    }

  while (lc_next (lc))
    {
      graph_node_id_t sub = vgraph_node_to_id_ex (lc_nth_col (lc, 0), qst);
      graph_node_id_t obj = vgraph_node_to_id_ex (lc_nth_col (lc, 1), qst);
      /* A NULL endpoint is not an edge, and vgraph_load_from_table()
       * skipped it, so there is no slot for its weight either. */
      if (GRAPH_NODE_ID_INVALID == sub || GRAPH_NODE_ID_INVALID == obj)
	continue;
      if (!weight_lookup_add (lookup, sub, obj, vgraph_weight_box_to_double (lc_nth_col (lc, 2))))
	{
	  result = GRAPH_ERR_OUT_OF_MEMORY;
	  goto cleanup;
	}
      if (lc->lc_error)
	{
	  vgraph_load_error_set (lc->lc_error);
	  result = GRAPH_ERR_IO_ERROR;
	  goto cleanup;
	}
    }

cleanup:
  if (lc)
    lc_free (lc);
  if (qr)
    qr_free (qr);
  if (exec_err)
    dk_free_tree (exec_err);
  return result;
}

static graph_error_t
build_weight_lookup_from_graph_unsorted (caddr_t *qst,
    graph_iri_id_t graph_iri, graph_iri_id_t weight_pred_iri, weight_lookup_t *lookup)
{
  if (!qst || !lookup || !weight_pred_iri)
    return GRAPH_ERR_NULL_PTR;

  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi ? qi->qi_client : NULL;
  /* Never fall back to the bootstrap (dba) connection: the weight scan
   * below reads RDF_QUAD and must run with the caller's own rights. */
  if (!cli)
    return GRAPH_ERR_NOT_INITIALIZED;

  /* This scan bypasses the SPARQL compiler's __rgs_ack filter just as the
   * main loader does, so it needs the same graph-level read check. */
  if (vgraph_graph_check_read (qst, graph_iri) != GRAPH_OK)
    return GRAPH_ERR_PERMISSION_DENIED;

  /* RDF 1.2 in Virtuoso stores triple-term weights as:
   *   <reifier:S:P:iO> <weight_pred> <weight_value> .
   * where the reifier IRI encodes the subject (S), predicate (P),
   * and object (O) IRI IDs of the base triple.
   *
   * We query for all triples in the graph with the weight predicate,
   * then parse the reifier IRI to extract S and O.
   *
   * We also try W3C reification as a fallback:
   *   ?stmt rdf:subject ?s ; rdf:object ?o ; <weight_pred> ?w .
   */
  ensure_reification_iris (qst);

  /* Query: find all weight triples in the graph.
   * SELECT ID_TO_IRI(S), O FROM DB.DBA.RDF_QUAD WHERE G = #i<graph> AND P = #i<weight_pred>
   * S is the reifier IRI ID; ID_TO_IRI converts it to the string form
   * (urn:rdf-star:reifier:S:P:iO) so we can parse out the subject/object.
   * O is the weight value. */
  /* Compile once and bind the ids as parameters.  This used to bake them
   * into the SQL text and sql_compile() a fresh plan on every call, which
   * on the scalar path meant an SQL compilation per row. */
  caddr_t err = NULL;
  if (!g_weight_qr)
    {
      caddr_t compile_err = NULL;
      dk_mutex_t *mtx = vgraph_scope_compile_mutex ();
      if (mtx)
	mutex_enter (mtx);
      if (!g_weight_qr)
	g_weight_qr = sql_compile_static ("SELECT ID_TO_IRI(S), O FROM DB.DBA.RDF_QUAD WHERE G = ? AND P = ?",
	    bootstrap_cli, &compile_err, SQLC_DEFAULT);
      if (mtx)
	mutex_leave (mtx);
      if (compile_err)
	{
	  vgraph_load_error_set (compile_err);
	  dk_free_tree (compile_err);
	}
    }
  if (!g_weight_qr)
    return GRAPH_ERR_IO_ERROR;

  local_cursor_t *lc = NULL;
  err = qr_rec_exec (g_weight_qr, cli, &lc, qi, NULL, 2,
      ":0", box_iri_id ((int64) graph_iri), QRP_RAW, ":1", box_iri_id ((int64) weight_pred_iri), QRP_RAW);
  if (err)
    {
      vgraph_load_error_set (err);
      dk_free_tree (err);
      if (lc)
	lc_free (lc);
      return GRAPH_ERR_IO_ERROR;
    }

  /* Allocate initial capacity.
   *
   * This starts at 64 and doubles, which on a graph with a weight per
   * edge ends at a 1.6 GB array reached through 20 doublings.  Sizing it
   * up front from a COUNT(*) -- 970 ms against the 112 s the loop takes
   * -- was tried and measured *worse* on a 16 GB machine: one 820 MB
   * allocation against a machine already holding a CSR and a buffer pool
   * costs more than the copying it saves.  Left as it is, deliberately;
   * if it is revisited, measure on a machine where a 112 s build is
   * reproducible, because this one swings 2-4x run to run. */
  lookup->capacity = 64;
  lookup->entries = (weight_entry_t *) dk_alloc (lookup->capacity * sizeof (weight_entry_t));
  lookup->count = 0;
  lookup->default_weight = 1.0;

  if (!lookup->entries)
    {
      /* lc_free() frees the query instance, which still references the
       * query, so the cursor always goes first. */
      lc_free (lc);
      return GRAPH_ERR_OUT_OF_MEMORY;
    }

  while (lc_next (lc))
    {
      caddr_t subj_box = lc_nth_col (lc, 0);
      caddr_t weight_box = lc_nth_col (lc, 1);
      graph_node_id_t src_id, obj_id;

      if (!subj_box || !weight_box)
	continue;
      if (DV_TYPE_OF (subj_box) == DV_DB_NULL || DV_TYPE_OF (weight_box) == DV_DB_NULL)
	continue;

      /* If we can't read the subject as a reifier IRI, skip: the other
       * two scans below pick up the forms that are not one. */
      if (!parse_reifier_iri (subj_box, &src_id, &obj_id))
	continue;

      if (!weight_lookup_add (lookup, src_id, obj_id, weight_value_to_double (weight_box)))
	{
	  wl_growth_failed (lookup->count);
	  break;
	}
    }

  lc_free (lc);

  /* Second scan: W3C reification pattern, expressed with plain triples
   * (no RDF 1.2 << >> syntax needed):
   *   ?stmt rdf:subject ?s ; rdf:predicate ?p ; rdf:object ?o ;
   *         <weight_pred> ?w .
   * The subject and object IRI IDs come straight from the rdf:subject /
   * rdf:object values, so no reifier-IRI parsing is required. */
  if (!g_reif_weight_qr)
    {
      caddr_t compile_err = NULL;
      dk_mutex_t *mtx = vgraph_scope_compile_mutex ();
      if (mtx)
	mutex_enter (mtx);
      if (!g_reif_weight_qr)
	g_reif_weight_qr = sql_compile_static ("SELECT rs.O, ro.O, rw.O FROM DB.DBA.RDF_QUAD rs, DB.DBA.RDF_QUAD rp, "
	    "DB.DBA.RDF_QUAD ro, DB.DBA.RDF_QUAD rw "
	    "WHERE rs.G = ? AND rs.P = ? "
	    "AND rp.G = rs.G AND rp.S = rs.S AND rp.P = ? "
	    "AND ro.G = rs.G AND ro.S = rs.S AND ro.P = ? "
	    "AND rw.G = rs.G AND rw.S = rs.S AND rw.P = ?", bootstrap_cli, &compile_err, SQLC_DEFAULT);
      if (mtx)
	mutex_leave (mtx);
      if (compile_err)
	dk_free_tree (compile_err);
    }
  if (!g_reif_weight_qr)
    return GRAPH_OK;		/* The first scan may have produced entries; keep them. */

  err = NULL;
  lc = NULL;
  err = qr_rec_exec (g_reif_weight_qr, cli, &lc, qi, NULL, 5,
      ":0", box_iri_id ((int64) graph_iri), QRP_RAW,
      ":1", box_iri_id ((int64) s_rdf_subject_iri), QRP_RAW,
      ":2", box_iri_id ((int64) s_rdf_predicate_iri), QRP_RAW,
      ":3", box_iri_id ((int64) s_rdf_object_iri), QRP_RAW, ":4", box_iri_id ((int64) weight_pred_iri), QRP_RAW);
  if (err)
    {
      dk_free_tree (err);
      if (lc)
	lc_free (lc);
      return GRAPH_OK;		/* Same: keep whatever the first scan produced. */
    }

  while (lc_next (lc))
    {
      caddr_t s_box = lc_nth_col (lc, 0);
      caddr_t o_box = lc_nth_col (lc, 1);
      caddr_t weight_box = lc_nth_col (lc, 2);

      if (!s_box || !o_box || !weight_box)
	continue;
      if (DV_TYPE_OF (s_box) == DV_DB_NULL || DV_TYPE_OF (o_box) == DV_DB_NULL || DV_TYPE_OF (weight_box) == DV_DB_NULL)
	continue;
      if (DV_TYPE_OF (s_box) != DV_IRI_ID && DV_TYPE_OF (s_box) != DV_IRI_ID_8)
	continue;
      if (DV_TYPE_OF (o_box) != DV_IRI_ID && DV_TYPE_OF (o_box) != DV_IRI_ID_8)
	continue;

      if (!weight_lookup_add (lookup, (graph_node_id_t) unbox_iri_id (s_box),
	      (graph_node_id_t) unbox_iri_id (o_box), weight_value_to_double (weight_box)))
	{
	  wl_growth_failed (lookup->count);
	  break;
	}
    }

  lc_free (lc);

  /* Third scan: the shape Virtuoso's Turtle parser actually produces for
   *   << <s> <p> <o> >> <weight_pred> ?w .
   * which is a blank-node reifier, not a reifier IRI:
   *   _:r rdf:reifies <urn:rdf-star:triple:S:P:iO> ; <weight_pred> ?w .
   * Without this the documented RDF 1.2 form loads cleanly and then
   * silently weighs every edge at the default. */
  /* rr.O is the triple term, and its IRI spells the three ids out:
   *   urn:rdf-star:triple:41259554:9982721:i41278231
   * So this materialises a 45-character string from an id and the loop
   * below parses the ids back out of it, once per weighted edge.  It
   * looks like exactly the wrong way round, and it was measured:
   *
   *   the two-table join alone                     2,639 ms
   *   the join returning rr.O as an id             1,855 ms
   *   the join with ID_TO_IRI forced              19,415 ms
   *   the whole scan, cursor and parsing         ~110,000 ms
   *
   * Doing the decode set-based instead --
   *   sprintf_inverse (ID_TO_IRI (rr.O), 'urn:rdf-star:triple:%s:%s:i%s', 1)
   * evaluated once in a derived table -- aggregates over all 34.2M rows
   * in 27,848 ms, so it reads like a 4x.  Implemented and measured, the
   * same scan took 158,137 ms against 107,115: about 45% *worse*.
   *
   * The aggregate was misleading.  Summing lets the engine avoid handing
   * 34.2 million rows to a client cursor; the real query cannot, and
   * three columns through that cursor cost more than one string does.
   * The cursor is the expense, not the parsing, and moving work out of
   * the loop does not help while the loop still runs 34.2M times.
   *
   * Two things for whoever picks this up.  Use %s and never %d: %d and
   * %ld truncate to 32 bits, IRI_IDs are 64-bit, and 9007199254740993
   * comes back as 1.  And write the guard as a derived table -- inline
   * as CASE WHEN length(...) >= 3 the optimiser does not fold the
   * repeated call and the same query takes 81,745 ms. */
  if (!g_reifies_weight_qr)
    {
      caddr_t compile_err = NULL;
      dk_mutex_t *mtx = vgraph_scope_compile_mutex ();
      if (mtx)
	mutex_enter (mtx);
      if (!g_reifies_weight_qr)
	g_reifies_weight_qr = sql_compile_static ("SELECT ID_TO_IRI(rr.O), rw.O FROM DB.DBA.RDF_QUAD rr, DB.DBA.RDF_QUAD rw "
	    "WHERE rr.G = ? AND rr.P = ? "
	    "AND rw.G = rr.G AND rw.S = rr.S AND rw.P = ?", bootstrap_cli, &compile_err, SQLC_DEFAULT);
      if (mtx)
	mutex_leave (mtx);
      if (compile_err)
	dk_free_tree (compile_err);
    }
  if (!g_reifies_weight_qr || !s_rdf_reifies_iri)
    return GRAPH_OK;

  err = NULL;
  lc = NULL;
  err = qr_rec_exec (g_reifies_weight_qr, cli, &lc, qi, NULL, 3,
      ":0", box_iri_id ((int64) graph_iri), QRP_RAW,
      ":1", box_iri_id ((int64) s_rdf_reifies_iri), QRP_RAW, ":2", box_iri_id ((int64) weight_pred_iri), QRP_RAW);
  if (err)
    {
      dk_free_tree (err);
      if (lc)
	lc_free (lc);
      return GRAPH_OK;
    }

  while (lc_next (lc))
    {
      caddr_t tt_box = lc_nth_col (lc, 0);
      caddr_t weight_box = lc_nth_col (lc, 1);
      graph_node_id_t src_id, obj_id;

      if (!tt_box || !weight_box)
	continue;
      if (DV_TYPE_OF (tt_box) == DV_DB_NULL || DV_TYPE_OF (weight_box) == DV_DB_NULL)
	continue;
      if (!parse_reifier_iri (tt_box, &src_id, &obj_id))
	continue;
      if (!weight_lookup_add (lookup, src_id, obj_id, weight_value_to_double (weight_box)))
	{
	  wl_growth_failed (lookup->count);
	  break;
	}
    }

  lc_free (lc);
  return GRAPH_OK;
}

/* ----------------------------------------------------------------------
 * Shared weight table.
 *
 * A table read out of a graph is a pure function of (graph, weight
 * predicate, cache generation), so rebuilding it per call is waste that
 * grows with the graph: one row of a per-vertex distance query would
 * otherwise rescan every weight triple in the store.  One slot is enough,
 * because a query asks for one weight predicate at a time; a second
 * predicate simply replaces it.
 *
 * Readers hold a reference for the duration of their call, so a table that
 * has been superseded stays alive until its last reader is done with it.
 * ---------------------------------------------------------------------- */

typedef struct weight_cache_entry
{
  graph_iri_id_t graph_iri;
  graph_iri_id_t pred_iri;
  uint64_t generation;
  /* Which table this is, as a number never handed out twice.  The
   * per-slot weight arrays are keyed on it: they hold one weight per CSR
   * slot resolved from *this* table, so they are valid while it is the
   * same table, which is a different question from whether anything has
   * been committed since.  A pointer would answer it wrongly -- the
   * allocator may hand a freed entry's address to its successor. */
  uint64_t build_id;
  weight_entry_t *entries;
  uint64_t count;
  uint64_t capacity;
  int32_t refs;
  bool retired;
  struct weight_cache_entry *next_retired;	/* on s_weight_retired */
} weight_cache_entry_t;

/* Assigned to every shared weight table.  See the comment on build_id. */
static uint64_t s_weight_build_seq = 0;

/* The build id of the table behind a lookup, or 0 when it has none -- a
 * private copy, or the SQL-vector form, whose only identity is its
 * contents.  Zero means "do not cache arrays against this", which is what
 * ew_entry_matches() does with it. */
static uint64_t
weight_lookup_build_id (const weight_lookup_t *wl)
{
  const weight_cache_entry_t *e = wl ? (const weight_cache_entry_t *) wl->shared : NULL;
  return e ? e->build_id : 0;
}

static dk_mutex_t *s_weight_cache_mtx = NULL;
/* Tables retired inside a commit, freed by the next weighted call: the
 * commit runs under the transaction mutex and must not pay for the free. */
static weight_cache_entry_t *s_weight_retired = NULL;
static weight_cache_entry_t *s_weight_cache = NULL;

static dk_mutex_t *
weight_cache_mutex (void)
{
  /* The scope compile mutex is already the module's one-time-init lock. */
  if (!s_weight_cache_mtx)
    {
      dk_mutex_t *outer = vgraph_scope_compile_mutex ();
      if (outer)
	mutex_enter (outer);
      if (!s_weight_cache_mtx)
	s_weight_cache_mtx = mutex_allocate ();
      if (outer)
	mutex_leave (outer);
    }
  return s_weight_cache_mtx;
}

static void
weight_cache_free_entry (weight_cache_entry_t *e)
{
  if (!e)
    return;
  if (e->entries)
    dk_free (e->entries, e->capacity * sizeof (weight_entry_t));
  dk_free (e, sizeof (weight_cache_entry_t));
}

static void
weight_cache_unref (void *shared)
{
  weight_cache_entry_t *e = (weight_cache_entry_t *) shared;
  dk_mutex_t *mtx;
  bool dispose = false;
  if (!e)
    return;
  mtx = weight_cache_mutex ();
  if (mtx)
    mutex_enter (mtx);
  if (--e->refs <= 0 && e->retired)
    dispose = true;
  if (mtx)
    mutex_leave (mtx);
  if (dispose)
    weight_cache_free_entry (e);
}

/* Retire the shared weight table if it belongs to this graph.
 *
 * A per-graph invalidation has to reach it.  It is keyed on the cache
 * generation, which is how it notices a write at all, and a per-graph
 * retirement deliberately does not move that -- so without this it would
 * go on serving a weight table built before the write.  This is the one
 * part of per-graph invalidation that is not local to the snapshot cache.
 *
 * The lazy mutex allocation in weight_cache_mutex() is deliberately not
 * forced from here: it takes the module's one-time-init lock, which is a
 * different lock order under the transaction mutex, and no mutex means
 * nothing has ever been cached anyway. */
static void
vgraph_weight_cache_retire_graph (graph_iri_id_t graph_iri)
{
  weight_cache_entry_t *old = NULL;
  if (!s_weight_cache_mtx)
    return;
  mutex_enter (s_weight_cache_mtx);
  if (s_weight_cache && !s_weight_cache->retired && s_weight_cache->graph_iri == graph_iri)
    {
      old = s_weight_cache;
      old->retired = true;
      s_weight_cache = NULL;
      s_gate_weights = 0;
      if (old->refs > 0)
	old = NULL;		/* its last reader disposes of it */
      if (old)
	{
	  old->next_retired = s_weight_retired;
	  s_weight_retired = old;
	  old = NULL;
	}
    }
  mutex_leave (s_weight_cache_mtx);
  /* Not vgraph_update_commit_gate() here: this runs inside lt_commit(),
   * under the transaction mutex, and lowering the gate from there would
   * let the very next commit skip a graph this one has just retired but
   * whose snapshot entry is still held.  The gate is recomputed by
   * whichever of the three terms next changes outside the commit. */
}

static void
vgraph_weight_reclaim_retired (dk_mutex_t *mtx)
{
  weight_cache_entry_t *list;
  if (!mtx)
    return;
  mutex_enter (mtx);
  list = s_weight_retired;
  s_weight_retired = NULL;
  mutex_leave (mtx);
  while (list)
    {
      weight_cache_entry_t *next = list->next_retired;
      weight_cache_free_entry (list);
      list = next;
    }
}

/* Weights a graph carries itself, rather than ones named by a predicate.
 *
 * A graph built from a query's own rows is the only kind that has any:
 * there is nowhere else they could come from, because a weight predicate
 * is read from the quad store and such a graph has no triples there.
 * That is why naming one used to be accepted and then quietly ignored,
 * handing back unweighted numbers to a caller who had asked for weighted
 * ones -- the compiler now refuses that combination, and here the
 * collected weights are simply the weights.
 *
 * Takes the IRI the caller named, not the private id: the private id is
 * this session's, and only the registry can map one to the other.
 *
 * True when it filled *lookup, which the caller then owns.  False means
 * this is an ordinary graph and the predicate path applies.  Not cached:
 * a transient graph belongs to one session and its edges are already in
 * memory, so rebuilding is cheaper than a cache entry keyed on a
 * predicate that has no part in it. */
static bool
vgraph_weight_lookup_from_edges (caddr_t *qst, graph_iri_id_t graph_iri, weight_lookup_t *lookup)
{
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi ? qi->qi_client : NULL;
  graph_iri_id_t private_id;
  graph_node_id_t *tedges = NULL;
  double *tweights = NULL;
  uint64_t tn = 0, i;
  graph_pred_id_t tpred = GRAPH_PRED_ID_INVALID;
  bool filled = false;

  if (!lookup || !graph_iri)
    return false;
  private_id = VGRAPH_IS_TRANSIENT (graph_iri) ? graph_iri : (cli ? vgraph_edge_src_private_id (graph_iri, cli) : 0);
  if (!private_id)
    return false;
  if (!vgraph_edge_src_get (private_id, &tedges, &tn, &tpred, &tweights))
    return false;
  if (tweights)
    {
      for (i = 0; i < tn; i++)
	{
	  if (!weight_lookup_add (lookup, tedges[i * 2], tedges[i * 2 + 1], tweights[i]))
	    break;
	}
      sort_weight_lookup (lookup);
      filled = true;
    }
  if (tedges)
    dk_free (tedges, (size_t) tn * 2 * sizeof (graph_node_id_t));
  if (tweights)
    dk_free (tweights, (size_t) tn * sizeof (double));
  return filled;
}

/* The builder above has several early returns that still leave usable
 * entries behind, so the ordering pass lives in a wrapper rather than at
 * each of them.  The wrapper is also where the shared table is consulted
 * and installed. */
static graph_error_t
build_weight_lookup_from_graph (caddr_t *qst, graph_iri_id_t graph_iri, graph_iri_id_t weight_pred_iri, weight_lookup_t *lookup)
{
  /* A weight predicate the store has never heard of: vgraph_iri_to_id_ex()
   * reports it as 0, and a mistyped IRI is exactly that.
   *
   * A graph that keeps its weights in a column needs no predicate.  One
   * registered by GRAPH_LOAD_TABLE (g, p, tbl, wcol) has no RDF behind
   * it, the predicate a caller names can never resolve, and the column
   * is the only candidate.  Group AP pins both spellings, because
   * iri_to_id() interns the IRI it is handed and so hides an unknown one
   * from any caller who writes it that way.
   *
   * Any other graph has no weights under such a predicate, and that is
   * the case the GRAPH_ERR_NO_WEIGHTS refusal below exists for.  This
   * used to return an empty table instead -- every edge at the default of
   * 1.0, the unweighted answer to a weighted question -- so the refusal
   * only ever saw a predicate the store knew, and the typo it names as
   * its commonest cause still got hop counts.  Refuse here too. */
  if (lookup && !weight_pred_iri)
    {
      char *probe_table = NULL, *probe_wcol = NULL;
      graph_pred_id_t probe_pred = GRAPH_PRED_ID_INVALID;
      bool from_column = vgraph_table_src_get (graph_iri, &probe_table,
	  &probe_wcol, &probe_pred) && probe_wcol;
      if (probe_table)
	dk_free_box (probe_table);
      if (probe_wcol)
	dk_free_box (probe_wcol);
      if (!from_column)
	return GRAPH_ERR_NO_WEIGHTS;
    }

  dk_mutex_t *mtx = weight_cache_mutex ();
  uint64_t generation;
  weight_cache_entry_t *hit = NULL, *fresh = NULL, *old = NULL;
  graph_error_t rc;
  /* Weights read with uncommitted rows in view are this transaction's
   * alone, and a rollback would not invalidate a published table. */
  bool private_build = VGRAPH_TXN_HAS_WRITES (qst);

  vgraph_weight_reclaim_retired (mtx);
  generation = gcache_get_generation ();

  if (mtx)
    mutex_enter (mtx);
  if (!private_build && s_weight_cache && !s_weight_cache->retired &&
      s_weight_cache->graph_iri == graph_iri &&
      s_weight_cache->pred_iri == weight_pred_iri && s_weight_cache->generation == generation)
    {
      hit = s_weight_cache;
      hit->refs++;
    }
  else if (s_weight_cache && !s_weight_cache->retired && s_weight_cache->generation != generation)
    {
      /* A commit has happened, so the cached table can never be reused.
       * Let it go before building its replacement rather than after: at
       * a weight per edge the two together are twice a table that can be
       * hundreds of megabytes. */
      old = s_weight_cache;
      old->retired = true;
      s_weight_cache = NULL;
      s_gate_weights = 0;
      if (old->refs > 0)
	old = NULL;		/* its last reader disposes of it */
    }
  /* About to read RDF_QUAD for a new table: the gate must be up before the
   * first row is read (see ltrx.h), not when the table is published, or a
   * write committing meanwhile skips the notifier and the table is served
   * as fresh.  The generation is re-read after raising it for that reason. */
  if (!hit)
    s_weight_builders++;
  if (mtx)
    mutex_leave (mtx);
  vgraph_update_commit_gate ();
  if (!hit)
    generation = gcache_get_generation ();
  if (old)
    {
      weight_cache_free_entry (old);
      old = NULL;
    }

  if (hit)
    {
      lookup->entries = hit->entries;
      lookup->count = hit->count;
      lookup->capacity = hit->capacity;
      lookup->default_weight = 1.0;
      lookup->sorted = true;
      lookup->shared = hit;
      lookup->from_graph = true;
      lookup->src_graph_iri = graph_iri;
      lookup->src_pred_iri = weight_pred_iri;
      lookup->src_generation = generation;
      return GRAPH_OK;
    }

  {
    uint32_t t0 = get_msec_real_time ();
    char *src_table = NULL, *src_wcol = NULL;
    graph_pred_id_t src_pred = GRAPH_PRED_ID_INVALID;
    s_wl_truncated = 0;
    /* A graph registered against a table with a weight column takes
     * its weights from that column, whatever weight predicate the
     * caller named.  There is no other candidate: the graph is not in
     * RDF_QUAD, so scanning it for a weight predicate would find
     * nothing and weigh every edge 1.0 -- which is the silent wrong
     * answer this file refuses elsewhere, and it is what happened
     * before this branch existed.
     *
     * The weight predicate still keys the shared table above, so two
     * callers naming different predicates get two entries with the
     * same contents.  That is a little waste and no ambiguity. */
    if (vgraph_table_src_get (graph_iri, &src_table, &src_wcol, &src_pred) && src_wcol)
      {
	rc = build_weight_lookup_from_table_unsorted (qst, src_table, src_wcol, lookup);
      }
    else
      {
	rc = build_weight_lookup_from_graph_unsorted (qst, graph_iri, weight_pred_iri, lookup);
      }
    if (src_table)
      dk_free_box (src_table);
    if (src_wcol)
      dk_free_box (src_wcol);
    s_wl_scan_ms = get_msec_real_time () - t0;
    s_wl_entries = lookup->count;
  }
  /* A table that ran out of memory part way is not a smaller table, it is
   * a wrong one: every edge past the cut takes the default weight, so a
   * weighted traversal returns distances that are too short and says
   * nothing.  Refuse it.  Failing a query is recoverable; answering it
   * incorrectly is not.
   *
   * Seen for real: a run on a machine with 32 MB of free pages returned
   * 3.0 for a vertex whose distance is 3.48837 -- three hops at the
   * default weight of 1.0 -- and validated as a wrong answer rather than
   * an error. */
  if (s_wl_truncated)
    {
      free_weight_lookup (lookup);
      memset (lookup, 0, sizeof (*lookup));
      rc = GRAPH_ERR_OUT_OF_MEMORY;
      goto build_done;
    }
  /* A weight predicate that matched nothing is the same failure one step
   * earlier: EVERY edge would take the default weight of 1.0, so the
   * caller asked a weighted question and would be handed the unweighted
   * answer with nothing to distinguish it.  Reached by an n-ary model
   * (:from/:to carry no rdf:subject/rdf:object for the reader to find),
   * by a mistyped predicate IRI, and by weights that live in a different
   * graph from the edges.
   *
   * Only the case where a weight predicate was actually named gets here:
   * a graph carrying its own weights, and a table registered with a
   * weight column, are both resolved earlier in
   * build_weight_lookup_unified() and return before this. */
  if (GRAPH_OK == rc && 0 == lookup->count && 0 != weight_pred_iri)
    {
      free_weight_lookup (lookup);
      memset (lookup, 0, sizeof (*lookup));
      rc = GRAPH_ERR_NO_WEIGHTS;
      goto build_done;
    }
  sort_weight_lookup (lookup);
  lookup->from_graph = true;
  lookup->src_graph_iri = graph_iri;
  lookup->src_pred_iri = weight_pred_iri;
  lookup->src_generation = generation;
  if (rc != GRAPH_OK || !lookup->entries || private_build)
    goto build_done;

  /* Publish it, handing our own allocation over to the cache and taking
   * a reference back, so the caller and the cache do not both own it. */
  fresh = (weight_cache_entry_t *) dk_alloc (sizeof (weight_cache_entry_t));
  if (!fresh)
    goto build_done;		/* keep the private copy */
  memset (fresh, 0, sizeof (weight_cache_entry_t));
  fresh->graph_iri = graph_iri;
  fresh->pred_iri = weight_pred_iri;
  fresh->generation = generation;
  fresh->build_id = ++s_weight_build_seq;
  fresh->entries = lookup->entries;
  fresh->count = lookup->count;
  fresh->capacity = lookup->capacity;
  fresh->refs = 1;

  if (mtx)
    mutex_enter (mtx);
  old = s_weight_cache;
  if (old)
    {
      old->retired = true;
      if (old->refs <= 0)
	{
	  s_weight_cache = NULL;
	}
      else
	old = NULL;		/* a reader disposes of it */
    }
  s_weight_cache = fresh;
  s_gate_weights = 1;
  if (mtx)
    mutex_leave (mtx);
  vgraph_update_commit_gate ();
  if (old)
    weight_cache_free_entry (old);

  lookup->shared = fresh;
build_done:
  if (mtx)
    mutex_enter (mtx);
  s_weight_builders--;
  if (mtx)
    mutex_leave (mtx);
  vgraph_update_commit_gate ();
  return rc;
}

/* ----------------------------------------------------------------------
 * Per-edge weights, resolved into CSR slot order.
 *
 * weighted_edge_lookup() searches the table once per relaxed edge -- twice
 * when the lookup is symmetric and the first probe misses, which on an
 * undirected graph is every backwards traversal of every edge.  At one
 * entry per edge that search is not an overhead on the traversal, it is
 * the traversal's cost: 34,185,747 entries is an 820 MB array, 25 levels
 * of bisection, and the probes arrive in visit order, so essentially all
 * of them miss cache.
 *
 * The traversal already knows which CSR slot it is standing on.  Resolving
 * the table into one weight per slot, once, turns each relaxation into an
 * indexed load.  The resolution asks the table the same questions in
 * ascending key order instead of visit order, which is what makes it
 * cheap, and asks them through the same code, which is what makes the
 * answers identical.
 *
 * Cached rather than rebuilt, because a per-vertex distance query calls
 * the BIF once per vertex and the whole-graph result cache means only the
 * first of those computes anything.  One slot, reference-counted the same
 * way the weight table is, so a superseded pair of arrays stays alive
 * until its last reader is done.
 *
 * Only tables read out of a graph get arrays.  The SQL-vector weight form
 * has no identity but its contents, and it is small by construction -- a
 * caller writing weights out by hand is not writing 34 million of them --
 * so there is nothing to win and a key that would cost a full scan to
 * compute.
 * ---------------------------------------------------------------------- */

typedef struct ew_cache_entry
{
  /* Which CSR, and which weight table.
   *
   * Both by build id, not by generation.  The arrays are indexed by CSR
   * slot and hold one weight per slot, so they are valid exactly while
   * the CSR and the weight table they were resolved from are the same
   * two objects -- and a build id says that, where a generation says
   * only "nothing has been committed since".  Those differ constantly:
   * a generation bump re-creates the cache entry over a graph that has
   * not changed, and the arrays used to be discarded with the entry.
   * Measured on 34,185,747 edges, the discard cost 4.6 s of resolve
   * every time and edge_weight_mismatch reported EW_MM_GEN |
   * EW_MM_SRCGEN -- both generation fields, neither of the things they
   * stand for.
   *
   * gkey is still compared: two predicate filters over one graph are
   * two CSRs, and a build id already separates them, but the key is what
   * makes that legible in the mismatch mask. */
  gcache_key_t gkey;
  uint64_t base_build_id;
  uint64_t node_count;
  uint64_t edge_count;
  /* Which weight table, and which question was asked of it. */
  graph_iri_id_t src_graph_iri;
  graph_iri_id_t src_pred_iri;
  uint64_t wl_build_id;
  uint64_t wl_count;
  double default_weight;
  bool symmetric;

  double *fwd;
  double *inv;
  uint64_t count;
  int32_t refs;
  bool retired;
} ew_cache_entry_t;

static dk_mutex_t *s_ew_cache_mtx = NULL;
static ew_cache_entry_t *s_ew_cache = NULL;
/* Reported by GRAPH_CACHE_STATUS.  Whether the arrays are in use is not
 * observable in an answer -- that is the point of them -- so it has to be
 * observable somewhere, or a test cannot tell a working fast path from a
 * silently declined one. */
static uint64_t s_ew_builds = 0;
static uint64_t s_ew_hits = 0;
static uint64_t s_ew_bytes = 0;

static dk_mutex_t *
ew_cache_mutex (void)
{
  if (!s_ew_cache_mtx)
    {
      dk_mutex_t *outer = vgraph_scope_compile_mutex ();
      if (outer)
	mutex_enter (outer);
      if (!s_ew_cache_mtx)
	s_ew_cache_mtx = mutex_allocate ();
      if (outer)
	mutex_leave (outer);
    }
  return s_ew_cache_mtx;
}

static void
ew_cache_free_entry (ew_cache_entry_t *e)
{
  size_t held;
  if (!e)
    return;
  held = (e->fwd ? e->count * sizeof (double) : 0) + (e->inv ? e->count * sizeof (double) : 0);
  if (e->fwd)
    dk_free (e->fwd, e->count * sizeof (double));
  if (e->inv)
    dk_free (e->inv, e->count * sizeof (double));
  dk_free (e, sizeof (ew_cache_entry_t));
  if (s_ew_bytes >= held)
    s_ew_bytes -= held;
  else
    s_ew_bytes = 0;
}

static void
vgraph_edge_weights_unref (void *token)
{
  ew_cache_entry_t *e = (ew_cache_entry_t *) token;
  dk_mutex_t *mtx;
  bool dispose = false;
  if (!e)
    return;
  mtx = ew_cache_mutex ();
  if (mtx)
    mutex_enter (mtx);
  if (--e->refs <= 0 && e->retired)
    dispose = true;
  if (mtx)
    mutex_leave (mtx);
  if (dispose)
    ew_cache_free_entry (e);
}

/* Retire whatever is cached.  Called when the feature is switched off, so
 * that turning it off releases the memory rather than merely stopping new
 * readers from taking it. */
static void
vgraph_edge_weights_drop (void)
{
  dk_mutex_t *mtx = ew_cache_mutex ();
  ew_cache_entry_t *old = NULL;
  if (mtx)
    mutex_enter (mtx);
  old = s_ew_cache;
  if (old)
    {
      old->retired = true;
      s_ew_cache = NULL;
      if (old->refs > 0)
	old = NULL;		/* its last reader disposes of it */
    }
  if (mtx)
    mutex_leave (mtx);
  if (old)
    ew_cache_free_entry (old);
}

/* The probe graph_base_resolve_edge_weights() drives.  Deliberately the
 * same weight_entry_find() weighted_edge_lookup() uses, so that the array
 * cannot drift from the lookup it stands in for. */
static bool
ew_probe (void *user_data, graph_node_id_t subject, graph_node_id_t object, double *out)
{
  const weight_lookup_t *wl = (const weight_lookup_t *) user_data;
  return weight_entry_find (wl, subject, object, out);
}

/* Why the per-slot weight arrays were last declined or missed.
 *
 * There was no way to tell a refusal from a cache miss from a failed
 * allocation: every one of them is a silent `return false` and the caller
 * quietly falls back to bisecting the weight table.  A weighted traversal
 * that is fifty times slower than it should be therefore looks exactly
 * like one that is working, and it took a whole benchmark session to
 * notice.  These two say which. */
static int s_ew_decline = 0;	/* EW_DECL_* below */
static int s_ew_mismatch = 0;	/* bitmask of ew_entry_matches fields */
/* Milliseconds the last per-slot array build spent in
 * graph_base_resolve_edge_weights().  Reported beside weight_scan_ms and
 * weight_sort_ms so the three costs a weighted traversal pays before it
 * moves are each a measurement rather than a remainder. */
static uint32_t s_ew_resolve_ms = 0;

#define EW_DECL_NONE        0	/* hit, or built successfully */
#define EW_DECL_OFF         1	/* GRAPH_SET_LIMIT('EdgeWeightArray', 0) */
#define EW_DECL_NO_TABLE    2	/* no weight lookup, or an empty one */
#define EW_DECL_NO_IDENTITY 3	/* table not from a graph, or unsorted */
#define EW_DECL_NO_ENTRY    4	/* graph not in the snapshot cache */
#define EW_DECL_NO_SNAP     5
#define EW_DECL_DELTA       6	/* uncompacted edges have no slot */
#define EW_DECL_NO_EDGES    7
#define EW_DECL_NO_INVERSE  8
#define EW_DECL_TOO_BIG     9	/* over [Graph] EdgeWeightMax */
#define EW_DECL_NO_MEMORY  10
#define EW_DECL_RESOLVE    11

#define EW_MM_KEY       0x001
#define EW_MM_BASE      0x002	/* a different CSR */
#define EW_MM_NODES     0x004
#define EW_MM_EDGES     0x008
#define EW_MM_GRAPH     0x010
#define EW_MM_PRED      0x020
#define EW_MM_WLBUILD   0x040	/* a different weight table */
#define EW_MM_WLCOUNT   0x080
#define EW_MM_DEFAULT   0x100
#define EW_MM_SYMMETRIC 0x200

static bool
ew_entry_matches (const ew_cache_entry_t *e, const gcache_key_t *gkey,
    uint64_t base_build_id, const graph_base_store_t *base, const weight_lookup_t *wl, bool symmetric)
{
  int mm = 0;
  if (!gcache_key_equals (&e->gkey, gkey))
    mm |= EW_MM_KEY;
  if (e->base_build_id != base_build_id || 0 == base_build_id)
    mm |= EW_MM_BASE;
  if (e->node_count != base->node_count)
    mm |= EW_MM_NODES;
  if (e->edge_count != base->edge_count)
    mm |= EW_MM_EDGES;
  if (e->src_graph_iri != wl->src_graph_iri)
    mm |= EW_MM_GRAPH;
  if (e->src_pred_iri != wl->src_pred_iri)
    mm |= EW_MM_PRED;
  if (e->wl_build_id != weight_lookup_build_id (wl) || 0 == weight_lookup_build_id (wl))
    mm |= EW_MM_WLBUILD;
  if (e->wl_count != wl->count)
    mm |= EW_MM_WLCOUNT;
  if (e->default_weight != wl->default_weight)
    mm |= EW_MM_DEFAULT;
  if (e->symmetric != symmetric)
    mm |= EW_MM_SYMMETRIC;
  s_ew_mismatch = mm;
  return 0 == mm;
}

/* Fill *out with per-slot weights for this call, taking a reference the
 * caller drops with vgraph_edge_weights_unref().  False means "use the
 * weight function" -- every refusal below is a reason the arrays would be
 * wrong, absent or not worth having, never a reason the answer changes. */
static bool
vgraph_edge_weights_get (const algo_context_t *ctx, const weight_lookup_t *wl, graph_edge_weights_t *out, void **out_token)
{
  const graph_base_store_t *base;
  const gcache_key_t *gkey;
  uint64_t base_build_id;
  dk_mutex_t *mtx;
  ew_cache_entry_t *hit = NULL, *fresh = NULL, *old = NULL;
  double *fwd = NULL, *inv = NULL;
  uint64_t count;
  bool symmetric;
  size_t bytes;

  out->fwd = out->inv = NULL;
  out->count = 0;
  *out_token = NULL;

  s_ew_decline = EW_DECL_NONE;
  if (!vgraph_edge_weight_array)
    {
      s_ew_decline = EW_DECL_OFF;
      return false;
    }
  if (!ctx || !wl || !wl->entries || !wl->count)
    {
      s_ew_decline = EW_DECL_NO_TABLE;
      return false;
    }
  /* No identity to key on, so no way to know a cached pair is this
   * table's. */
  if (!wl->from_graph || !wl->sorted)
    {
      s_ew_decline = EW_DECL_NO_IDENTITY;
      return false;
    }
  /* No graph-cache entry means no stable identity for the CSR either. */
  if (!ctx->owns_cache || !ctx->cache_handle.entry)
    {
      s_ew_decline = EW_DECL_NO_ENTRY;
      return false;
    }
  if (!ctx->snapshot || !ctx->snapshot->graph)
    {
      s_ew_decline = EW_DECL_NO_SNAP;
      return false;
    }
  /* Slots only cover the CSR.  With a delta chain the traversal reads
   * edges that have no slot, and refuses the arrays anyway. */
  if (ctx->snapshot->delta_head)
    {
      s_ew_decline = EW_DECL_DELTA;
      return false;
    }

  base = ctx->snapshot->graph->base;
  if (!base || !base->edge_count)
    {
      s_ew_decline = EW_DECL_NO_EDGES;
      return false;
    }
  if (!base->has_inverse)
    {
      s_ew_decline = EW_DECL_NO_INVERSE;
      return false;
    }

  count = base->edge_count;
  bytes = (size_t) count *sizeof (double) * 2;
  if (vgraph_edge_weight_max && bytes > vgraph_edge_weight_max)
    {
      s_ew_decline = EW_DECL_TOO_BIG;
      return false;
    }

  gkey = &ctx->cache_handle.entry->key;
  /* Which CSR, not which generation.  See ew_cache_entry_t. */
  base_build_id = base->build_id;
  symmetric = wl->symmetric;

  mtx = ew_cache_mutex ();
  if (mtx)
    mutex_enter (mtx);
  if (s_ew_cache && !s_ew_cache->retired && ew_entry_matches (s_ew_cache, gkey, base_build_id, base, wl, symmetric))
    {
      hit = s_ew_cache;
      hit->refs++;
    }
  if (mtx)
    mutex_leave (mtx);

  if (hit)
    {
      s_ew_hits++;
      out->fwd = hit->fwd;
      out->inv = hit->inv;
      out->count = hit->count;
      *out_token = hit;
      return true;
    }

  fwd = (double *) dk_alloc (count * sizeof (double));
  if (!fwd)
    {
      s_ew_decline = EW_DECL_NO_MEMORY;
      return false;
    }
  inv = (double *) dk_alloc (count * sizeof (double));
  if (!inv)
    {
      dk_free (fwd, count * sizeof (double));
      s_ew_decline = EW_DECL_NO_MEMORY;
      return false;
    }

  {
    /* Timed because it is the third of the three costs a weighted
     * traversal pays before it starts, and the only one that had no
     * number: reading the weights out of the source, sorting them, and
     * resolving one per CSR slot.  Attributing the wall clock by
     * subtraction is what made the first two wrong. */
    uint32_t t0 = get_msec_real_time ();
    graph_error_t rerr = graph_base_resolve_edge_weights (base, ew_probe,
	(void *) wl, symmetric,
	wl->default_weight, fwd, inv);
    s_ew_resolve_ms = get_msec_real_time () - t0;
    if (rerr != GRAPH_OK)
      {
	dk_free (fwd, count * sizeof (double));
	dk_free (inv, count * sizeof (double));
	s_ew_decline = EW_DECL_RESOLVE;
	return false;
      }
  }

  fresh = (ew_cache_entry_t *) dk_alloc (sizeof (ew_cache_entry_t));
  if (!fresh)
    {
      dk_free (fwd, count * sizeof (double));
      dk_free (inv, count * sizeof (double));
      return false;
    }
  memset (fresh, 0, sizeof (ew_cache_entry_t));
  fresh->gkey = *gkey;
  fresh->base_build_id = base_build_id;
  fresh->node_count = base->node_count;
  fresh->edge_count = base->edge_count;
  fresh->src_graph_iri = wl->src_graph_iri;
  fresh->src_pred_iri = wl->src_pred_iri;
  fresh->wl_build_id = weight_lookup_build_id (wl);
  fresh->wl_count = wl->count;
  fresh->default_weight = wl->default_weight;
  fresh->symmetric = symmetric;
  fresh->fwd = fwd;
  fresh->inv = inv;
  fresh->count = count;
  fresh->refs = 1;

  /* Publish, letting the superseded pair go first: two of these together
   * is 16 bytes an edge twice over. */
  if (mtx)
    mutex_enter (mtx);
  old = s_ew_cache;
  if (old)
    {
      old->retired = true;
      if (old->refs > 0)
	old = NULL;		/* a reader disposes of it */
    }
  s_ew_cache = fresh;
  s_ew_builds++;
  s_ew_bytes += bytes;
  if (mtx)
    mutex_leave (mtx);
  if (old)
    ew_cache_free_entry (old);

  out->fwd = fresh->fwd;
  out->inv = fresh->inv;
  out->count = fresh->count;
  *out_token = fresh;
  return true;
}

/* Unified weight lookup builder.
 * Dispatches based on the type of weight_arg:
 * - DV_IRI_ID / DV_IRI_ID_8: weight_arg is a weight predicate IRI;
 *   reads weights from RDF reification patterns in the graph.
 * - DV_ARRAY_OF_POINTER / DV_LIST_OF_POINTER: weight_arg is a VECTOR of
 *   [subject, object, weight] triples; builds lookup from the vector.
 *
 * graph_arg is the graph IRI (needed for reification mode).
 * Returns GRAPH_OK on success, error code on failure. */

/* Forward declaration - build_weight_lookup is defined below */
static void build_weight_lookup (caddr_t weight_arg, weight_lookup_t * lookup, caddr_t * qst);

static graph_error_t
build_weight_lookup_unified (caddr_t *qst, caddr_t weight_arg, caddr_t graph_arg, weight_lookup_t *lookup)
{
  if (!lookup)
    return GRAPH_ERR_NULL_PTR;
  lookup->default_weight = 1.0;

  /* A graph that carries its own weights answers first, and answers
   * even when no weight argument was given -- for a graph collected
   * from a query's rows there is no predicate to give. */
  {
    graph_iri_id_t g_iri = 0;
    if (graph_arg && DV_TYPE_OF (graph_arg) != DV_DB_NULL)
      g_iri = vgraph_iri_to_id_ex (graph_arg, qst);
    if (vgraph_weight_lookup_from_edges (qst, g_iri, lookup))
      return GRAPH_OK;
  }
  if (!weight_arg)
    return GRAPH_ERR_NULL_PTR;

  int wtag = DV_TYPE_OF (weight_arg);
  if (wtag == DV_IRI_ID || wtag == DV_IRI_ID_8 ||
      wtag == DV_STRING || wtag == DV_SHORT_STRING || wtag == DV_LONG_STRING || wtag == DV_UNAME)
    {
      /* Reification mode: weight_arg is a weight predicate IRI.
       * Read weights from RDF reification/RDF 1.2 patterns in the graph. */
      graph_iri_id_t weight_pred_iri = vgraph_iri_to_id_ex (weight_arg, qst);
      graph_iri_id_t graph_iri = 0;
      if (graph_arg && DV_TYPE_OF (graph_arg) != DV_DB_NULL)
	graph_iri = vgraph_iri_to_id_ex (graph_arg, qst);
      return build_weight_lookup_from_graph (qst, graph_iri, weight_pred_iri, lookup);
    }

  /* Vector mode: build from [subject, object, weight] triples */
  build_weight_lookup (weight_arg, lookup, qst);
  return GRAPH_OK;
}

/* Helper to build weight lookup from a vector argument */
static void
build_weight_lookup (caddr_t weight_arg, weight_lookup_t *lookup, caddr_t *qst)
{
  if (!weight_arg)
    return;
  int tag = DV_TYPE_OF (weight_arg);
  /* Accept both array types - SQL VECTOR() may create either */
  if (tag != DV_ARRAY_OF_POINTER && tag != DV_LIST_OF_POINTER)
    return;

  uint64_t wcount = BOX_ELEMENTS (weight_arg);
  lookup->entries = (weight_entry_t *) dk_alloc (wcount * sizeof (weight_entry_t));
  lookup->capacity = wcount;
  lookup->default_weight = 1.0;

  if (lookup->entries)
    {
      caddr_t *warr = (caddr_t *) weight_arg;
      for (uint64_t i = 0; i < wcount; i++)
	{
	  if (!warr[i])
	    continue;
	  int row_tag = DV_TYPE_OF (warr[i]);
	  /* Accept both array types for row entries */
	  if ((row_tag != DV_ARRAY_OF_POINTER && row_tag != DV_LIST_OF_POINTER) || BOX_ELEMENTS (warr[i]) < 3)
	    continue;

	  caddr_t *entry = (caddr_t *) warr[i];
	  /* Use vgraph_node_to_id_ex with qst to match how vgraph_load_from_vector_ex converts nodes */
	  lookup->entries[lookup->count].subject = vgraph_node_to_id_ex (entry[0], qst);
	  lookup->entries[lookup->count].object = vgraph_node_to_id_ex (entry[1], qst);

	  /* Extract the weight through the one converter that knows every
	   * box tag.  What was here tested DV_DOUBLE_PREC - a column type
	   * code, not a box tag - so a double weight read as 1.0, and it
	   * handed a DV_NUMERIC box to atof() as though it were a C
	   * string. */
	  lookup->entries[lookup->count].weight = weight_value_to_double (entry[2]);
	  lookup->count++;
	}
    }
  sort_weight_lookup (lookup);
}

/* Helper to find node index in snapshot */
uint64_t
find_node_index (const graph_snapshot_t *snapshot, graph_node_id_t node_id)
{
  if (!snapshot)
    return UINT64_MAX;
  /* Use the snapshot's hash-based node lookup, which works across
   * base store and delta chain.  Falls back to linear scan of the
   * base store only if the hash map hasn't been built. */
  uint64_t idx = graph_snapshot_find_node (snapshot, node_id);
  if (idx != UINT64_MAX)
    return idx;
  /* Fallback: linear scan of base store node IDs */
  if (snapshot->graph && snapshot->graph->base)
    {
      const graph_base_store_t *base = snapshot->graph->base;
      for (uint64_t i = 0; i < base->node_count; i++)
	{
	  if (base->node_ids[i] == node_id)
	    return i;
	}
    }
  return UINT64_MAX;
}

/* ============================================================================
 * BIF: GRAPH_SHORTEST_PATH_WEIGHTED
 *
 * SQL: GRAPH_SHORTEST_PATH_WEIGHTED(from_node, to_node, graph_iri, predicate_iri,
 *                                    weight_arg, return_type)
 * weight_arg: Either a SQL VECTOR of [subject, object, weight] triples,
 *             OR an IRI ID of a weight predicate to read from RDF reification.
 * Returns: ARRAY - path with weighted costs
 * ============================================================================ */

static caddr_t
bif_graph_shortest_path_weighted (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t from_arg = bif_arg (qst, args, 0, "GRAPH_SHORTEST_PATH_WEIGHTED");
  caddr_t to_arg = bif_arg (qst, args, 1, "GRAPH_SHORTEST_PATH_WEIGHTED");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_SHORTEST_PATH_WEIGHTED") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_SHORTEST_PATH_WEIGHTED") : NULL;
  caddr_t weight_arg = BOX_ELEMENTS (args) > 4 ? bif_arg (qst, args, 4, "GRAPH_SHORTEST_PATH_WEIGHTED") : NULL;
  caddr_t return_type_arg = BOX_ELEMENTS (args) > 5 ? bif_arg (qst, args, 5, "GRAPH_SHORTEST_PATH_WEIGHTED") : NULL;
  caddr_t direction_arg = BOX_ELEMENTS (args) > 6 ? bif_arg (qst, args, 6, "GRAPH_SHORTEST_PATH_WEIGHTED") : NULL;

  int return_type = 0;
  if (return_type_arg && DV_TYPE_OF (return_type_arg) != DV_DB_NULL)
    {
      return_type = (int) unbox (return_type_arg);
    }

  /* Without this the weighted traversal was outgoing-only, so an
   * undirected graph stored one direction per edge could not be asked
   * for a shortest path at all. */
  int direction = 0;
  {
    graph_direction_t gd;
    if (vgraph_direction_arg (direction_arg, VGRAPH_DIRENC_TRAVERSAL, GRAPH_DIR_OUTGOING, &gd))
      {
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGSPW07",
	    "GRAPH_SHORTEST_PATH_WEIGHTED: direction must be 0 or 'out', 1 or 'in', 2 or 'both'");
	return NULL;
      }
    direction = (int) gd;
  }

  if (!from_arg || DV_TYPE_OF (from_arg) == DV_DB_NULL || !to_arg || DV_TYPE_OF (to_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGSPW01", "GRAPH_SHORTEST_PATH_WEIGHTED: node argument is NULL");
      return NULL;
    }

  graph_node_id_t from_node = vgraph_node_to_id_ex (from_arg, qst);
  graph_node_id_t to_node = vgraph_node_to_id_ex (to_arg, qst);

  if (from_node == GRAPH_NODE_ID_INVALID || to_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGSPW02", "GRAPH_SHORTEST_PATH_WEIGHTED: invalid node IRI");
      return NULL;
    }

  /* Build weight lookup table.
   * Two modes: IRI ID (reification) or VECTOR of [s, o, w] triples. */
  weight_lookup_t weight_lookup = { 0 };
  graph_error_t wlerr = build_weight_lookup_unified (qst, weight_arg, graph_arg, &weight_lookup);
  if (wlerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGSPW04",
	  "GRAPH_SHORTEST_PATH_WEIGHTED: failed to load weights: %s", vgraph_load_reason (wlerr, qst));
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGSPW03",
	  "GRAPH_SHORTEST_PATH_WEIGHTED: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* SSSP: one Dijkstra per (snapshot, source, weights), cached like the
   * other whole-graph results, with {distances[V], parents[V]} as the
   * payload.  Repeated calls from the same source under the same weights
   * - the one-source-many-targets shape - now cost one traversal in
   * total. */
  ctx.src_node = from_node;
  ctx.weight_lookup = &weight_lookup;
  ctx.weight_direction = direction;
  /* Walking both ways means an edge can be relaxed from either end. */
  weight_lookup.symmetric = (direction == 2);

  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_sssp, &br);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_NOT_FOUND)
    {
      bool no_ws = (GRAPH_ERR_OUT_OF_MEMORY == gerr && !ctx.workspace);
      size_t need = no_ws ? graph_algo_dijkstra_workspace_size (ctx.snapshot) : 0;
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      free_weight_lookup (&weight_lookup);
      if (!*err_ret)
	{
	  if (no_ws)
	    vgraph_workspace_error (err_ret, "GRAPH_SHORTEST_PATH_WEIGHTED", "VGSPW04", need);
	  else
	    *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGSPW05",
		"GRAPH_SHORTEST_PATH_WEIGHTED: algorithm failed: %s", graph_error_string (gerr));
	}
      return NULL;
    }

  const double *distances = (const double *) br.payload;
  const graph_node_id_t *parents = vgraph_payload_parents (&br);
  uint64_t to_idx = find_node_index (ctx.snapshot, to_node);
  double total_cost = INFINITY;
  if (distances && UINT64_MAX != to_idx && to_idx < br.node_count)
    total_cost = distances[to_idx];

  if (!distances || !parents || UINT64_MAX == to_idx || total_cost == INFINITY)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      free_weight_lookup (&weight_lookup);
      return NEW_DB_NULL;	/* No path exists */
    }

  /* Reconstruct path by walking parents backwards */
  uint64_t path_capacity = br.node_count;
  size_t path_nodes_size = path_capacity * sizeof (graph_node_id_t);
  size_t path_costs_size = path_capacity * sizeof (double);
  graph_node_id_t *path_nodes = (graph_node_id_t *) dk_alloc (path_nodes_size);
  double *path_costs = (double *) dk_alloc (path_costs_size);
  if (!path_nodes || !path_costs)
    {
      if (path_nodes)
	dk_free (path_nodes, path_nodes_size);
      if (path_costs)
	dk_free (path_costs, path_costs_size);
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, "VGSPW06", "GRAPH_SHORTEST_PATH_WEIGHTED: path allocation failed");
      return NULL;
    }

  /* Build path backwards from target to source */
  uint64_t path_len = 0;
  graph_node_id_t current = to_node;
  while (path_len < path_capacity)
    {
      uint64_t current_idx = find_node_index (ctx.snapshot, current);
      if (current_idx == UINT64_MAX || current_idx >= br.node_count)
	break;

      path_nodes[path_len] = current;
      path_costs[path_len] = distances[current_idx];
      path_len++;

      if (current == from_node)
	break;
      current = parents[current_idx];
      if (current == GRAPH_NODE_ID_INVALID)
	break;
    }

  /* Reverse the path */
  for (uint64_t i = 0; i < path_len / 2; i++)
    {
      graph_node_id_t tmp_node = path_nodes[i];
      double tmp_cost = path_costs[i];
      path_nodes[i] = path_nodes[path_len - 1 - i];
      path_costs[i] = path_costs[path_len - 1 - i];
      path_nodes[path_len - 1 - i] = tmp_node;
      path_costs[path_len - 1 - i] = tmp_cost;
    }

  caddr_t ret_val;

  if (return_type == 1)
    {
      /* Neo4j-style: vector(nodeNames, costs, totalCost) */
      caddr_t *node_names = (caddr_t *) dk_alloc_box (path_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      caddr_t *costs = (caddr_t *) dk_alloc_box (path_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

      for (uint64_t i = 0; i < path_len; i++)
	{
	  caddr_t iri = vgraph_id_to_iri_ex (path_nodes[i], qst);
	  node_names[i] = iri ? iri : NEW_DB_NULL;
	  costs[i] = box_double (path_costs[i]);
	}

      caddr_t *result_arr = (caddr_t *) dk_alloc_box (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      result_arr[0] = (caddr_t) node_names;
      result_arr[1] = (caddr_t) costs;
      result_arr[2] = box_double (total_cost);
      ret_val = (caddr_t) result_arr;
    }
  else
    {
      /* Default: simple vector of node IRIs */
      caddr_t *path_iris = (caddr_t *) dk_alloc_box (path_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (uint64_t i = 0; i < path_len; i++)
	{
	  caddr_t iri = vgraph_id_to_iri_ex (path_nodes[i], qst);
	  path_iris[i] = iri ? iri : NEW_DB_NULL;
	}
      ret_val = (caddr_t) path_iris;
    }

  dk_free (path_nodes, path_nodes_size);
  dk_free (path_costs, path_costs_size);
  vgraph_payload_release (&br);
  free_weight_lookup (&weight_lookup);
  cleanup_algo_context (&ctx);
  return ret_val;
}

/* ============================================================================
 * BIF: GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED
 *
 * SQL: GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED(from_node, to_node, graph_iri,
 *                                          predicate_iri, weight_arg, direction)
 * Returns: DOUBLE - total cost of the cheapest path, NULL when unreachable.
 *
 * The weighted counterpart of GRAPH_SHORTEST_PATH_LENGTH.  It reads
 * distances[to] straight out of the {distances, parents} payload the
 * traversal already cached, where the path form would rebuild and then
 * discard a path per row.  A query that wants one cost per vertex is the
 * ordinary shape, and it should not pay for paths nobody looks at.
 * ============================================================================ */

static caddr_t
bif_graph_shortest_path_length_weighted (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t from_arg = bif_arg (qst, args, 0, "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED");
  caddr_t to_arg = bif_arg (qst, args, 1, "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED") : NULL;
  caddr_t weight_arg = BOX_ELEMENTS (args) > 4 ? bif_arg (qst, args, 4, "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED") : NULL;
  caddr_t direction_arg = BOX_ELEMENTS (args) > 5 ? bif_arg (qst, args, 5, "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED") : NULL;

  if (!from_arg || DV_TYPE_OF (from_arg) == DV_DB_NULL || !to_arg || DV_TYPE_OF (to_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGSLW01",
	  "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED: node argument is NULL");
      return NULL;
    }

  int direction = 0;
  {
    graph_direction_t gd;
    if (vgraph_direction_arg (direction_arg, VGRAPH_DIRENC_TRAVERSAL, GRAPH_DIR_OUTGOING, &gd))
      {
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGSLW07",
	    "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED: direction must be 0 or 'out', 1 or 'in', 2 or 'both'");
	return NULL;
      }
    direction = (int) gd;
  }

  graph_node_id_t from_node = vgraph_node_to_id_ex (from_arg, qst);
  graph_node_id_t to_node = vgraph_node_to_id_ex (to_arg, qst);
  if (from_node == GRAPH_NODE_ID_INVALID || to_node == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGSLW02",
	  "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED: invalid node IRI");
      return NULL;
    }

  weight_lookup_t weight_lookup = { 0 };
  graph_error_t wlerr = build_weight_lookup_unified (qst, weight_arg, graph_arg, &weight_lookup);
  if (wlerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGSLW04",
	  "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED: failed to load weights: %s", vgraph_load_reason (wlerr, qst));
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGSLW03",
	  "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  ctx.src_node = from_node;
  ctx.weight_lookup = &weight_lookup;
  ctx.weight_direction = direction;
  /* Walking both ways means an edge can be relaxed from either end. */
  weight_lookup.symmetric = (direction == 2);

  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_sssp, &br);
  if (gerr != GRAPH_OK && gerr != GRAPH_ERR_NOT_FOUND)
    {
      bool no_ws = (GRAPH_ERR_OUT_OF_MEMORY == gerr && !ctx.workspace);
      size_t need = no_ws ? graph_algo_dijkstra_workspace_size (ctx.snapshot) : 0;
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      free_weight_lookup (&weight_lookup);
      if (!*err_ret)
	{
	  if (no_ws)
	    vgraph_workspace_error (err_ret, "GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED", "VGSLW04", need);
	  else
	    *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGSLW05",
		"GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED: algorithm failed: %s", graph_error_string (gerr));
	}
      return NULL;
    }

  const double *distances = (const double *) br.payload;
  uint64_t to_idx = find_node_index (ctx.snapshot, to_node);
  caddr_t ret;
  if (!distances || UINT64_MAX == to_idx || to_idx >= br.node_count || distances[to_idx] == INFINITY)
    ret = NEW_DB_NULL;
  else
    ret = box_double (distances[to_idx]);

  vgraph_payload_release (&br);
  free_weight_lookup (&weight_lookup);
  cleanup_algo_context (&ctx);
  return ret;
}

/* ============================================================================
 * BIF: GRAPH_PAGERANK_WEIGHTED
 *
 * SQL: GRAPH_PAGERANK_WEIGHTED(node_iri, graph_iri, predicate_iri, weight_arg)
 * weight_arg: Either a SQL VECTOR of [subject, object, weight] triples,
 *             OR an IRI ID of a weight predicate (e.g. iri_to_id(':weight'))
 *             to read weights from RDF reification patterns in the graph.
 * Returns: DOUBLE - weighted PageRank score
 * ============================================================================ */

static caddr_t
bif_graph_pagerank_weighted (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_PAGERANK_WEIGHTED");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_PAGERANK_WEIGHTED") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_PAGERANK_WEIGHTED") : NULL;
  caddr_t weight_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_PAGERANK_WEIGHTED") : NULL;
  /* The same four the unweighted form takes, in the same order after
   * the weight.  They used to be read by the parser, validated, and
   * then dropped -- this BIF passed NULL for the parameter block, so
   * the algorithm used its own defaults and a query asking for damping
   * 0.5 got 0.85 and a plausible number back. */
  graph_pagerank_params_t pr_params = GRAPH_PAGERANK_DEFAULT;
  int nargs_pr = BOX_ELEMENTS (args);
  if (nargs_pr > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_PAGERANK_WEIGHTED");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  pr_params.damping = vgraph_box_to_double (a);
	  if (pr_params.damping <= 0.0 || pr_params.damping >= 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPRW06",
		  "GRAPH_PAGERANK_WEIGHTED: damping must be in (0,1), got %g", pr_params.damping);
	      return NULL;
	    }
	}
    }
  if (nargs_pr > 5)
    {
      caddr_t a = bif_arg (qst, args, 5, "GRAPH_PAGERANK_WEIGHTED");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  int64_t mi = unbox (a);
	  if (mi < 1 || mi > 100000)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPRW07",
		  "GRAPH_PAGERANK_WEIGHTED: max_iter must be in [1,100000], got %ld", (long) mi);
	      return NULL;
	    }
	  pr_params.max_iterations = (int) mi;
	}
    }
  if (nargs_pr > 6)
    {
      caddr_t a = bif_arg (qst, args, 6, "GRAPH_PAGERANK_WEIGHTED");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  pr_params.epsilon = vgraph_box_to_double (a);
	  if (pr_params.epsilon <= 0.0 || pr_params.epsilon >= 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGPRW08",
		  "GRAPH_PAGERANK_WEIGHTED: tolerance must be in (0,1), got %g", pr_params.epsilon);
	      return NULL;
	    }
	}
    }
  if (nargs_pr > 7)
    {
      caddr_t a = bif_arg (qst, args, 7, "GRAPH_PAGERANK_WEIGHTED");
      /* No `a &&` here.  Virtuoso boxes a small integer inline, so the
       * integer 0 -- a legal value for this flag, unlike damping or
       * max_iter -- is the same pointer as C NULL and a pointer test
       * skips the argument, leaving the default.  It cost `directed 0`
       * over a SERVICE result: accepted, range-checked, then ignored,
       * while `directed 0.0` worked.  DV_TYPE_OF() already reports a
       * real SQL NULL as DV_DB_NULL, which is a box. */
      if (DV_TYPE_OF (a) != DV_DB_NULL)
	pr_params.directed = (0 != unbox (a));
    }

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGPRW01", "GRAPH_PAGERANK_WEIGHTED: node argument is NULL");
      return NULL;
    }

  graph_node_id_t node_id = vgraph_node_to_id_ex (node_arg, qst);
  if (node_id == GRAPH_NODE_ID_INVALID)
    {
      return box_double (0.0);
    }

  /* Build weight lookup table.
   * Two modes:
   * 1. weight_arg is a VECTOR of [subject, object, weight] triples
   * 2. weight_arg is an IRI ID (weight predicate) -> read from graph reification
   */
  weight_lookup_t weight_lookup = { 0 };
  weight_lookup.default_weight = 1.0;

  /* A graph collected from a query's own rows carries its weights, and
   * carries them with no weight argument at all -- there is no
   * predicate to name for a graph that has no triples in the store. */
  {
    graph_iri_id_t own_iri = 0;
    if (graph_arg && DV_TYPE_OF (graph_arg) != DV_DB_NULL)
      own_iri = vgraph_iri_to_id_ex (graph_arg, qst);
    vgraph_weight_lookup_from_edges (qst, own_iri, &weight_lookup);
  }

  int warg_tag = weight_arg ? DV_TYPE_OF (weight_arg) : 0;
  if (!weight_lookup.count && weight_arg &&
      (warg_tag == DV_IRI_ID || warg_tag == DV_IRI_ID_8 ||
	  warg_tag == DV_STRING || warg_tag == DV_SHORT_STRING || warg_tag == DV_LONG_STRING || warg_tag == DV_UNAME))
    {
      /* Mode 2: weight_arg is a weight predicate IRI.
       * Read weights from RDF reification/RDF 1.2 patterns in the graph. */
      graph_iri_id_t weight_pred_iri = vgraph_iri_to_id_ex (weight_arg, qst);
      graph_iri_id_t graph_iri = 0;
      if (graph_arg && DV_TYPE_OF (graph_arg) != DV_DB_NULL)
	graph_iri = vgraph_iri_to_id_ex (graph_arg, qst);
      graph_error_t wlerr = build_weight_lookup_from_graph (qst, graph_iri,
	  weight_pred_iri, &weight_lookup);
      if (wlerr != GRAPH_OK)
	{
	  free_weight_lookup (&weight_lookup);
	  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGPRW04",
	      "GRAPH_PAGERANK_WEIGHTED: failed to load weights from graph: %s", vgraph_load_reason (wlerr, qst));
	  return NULL;
	}
    }
  else if (weight_arg && (warg_tag == DV_ARRAY_OF_POINTER || warg_tag == DV_LIST_OF_POINTER))
    {
      uint64_t wcount = BOX_ELEMENTS (weight_arg);
      weight_lookup.entries = (weight_entry_t *) dk_alloc (wcount * sizeof (weight_entry_t));
      weight_lookup.capacity = wcount;

      if (weight_lookup.entries)
	{
	  caddr_t *warr = (caddr_t *) weight_arg;
	  for (uint64_t i = 0; i < wcount; i++)
	    {
	      int entry_tag = warr[i] ? DV_TYPE_OF (warr[i]) : 0;
	      if (warr[i] && (entry_tag == DV_ARRAY_OF_POINTER || entry_tag == DV_LIST_OF_POINTER) && BOX_ELEMENTS (warr[i]) >= 3)
		{
		  caddr_t *entry = (caddr_t *) warr[i];
		  weight_lookup.entries[weight_lookup.count].subject = vgraph_node_to_id_ex (entry[0], qst);
		  weight_lookup.entries[weight_lookup.count].object = vgraph_node_to_id_ex (entry[1], qst);
		  /* Extract numeric weight - handle various Virtuoso numeric types */
		  int wtype = DV_TYPE_OF (entry[2]);
		  double w = 1.0;
		  if (wtype == DV_DOUBLE_FLOAT)
		    {
		      w = unbox_double (entry[2]);
		    }
		  else if (wtype == DV_SINGLE_FLOAT)
		    {
		      w = (double) unbox_float (entry[2]);
		    }
		  else if (wtype == DV_LONG_INT || wtype == DV_SHORT_INT || wtype == DV_INT64)
		    {
		      w = (double) unbox (entry[2]);
		    }
		  else if (wtype == DV_NUMERIC)
		    {
		      numeric_to_double ((numeric_t) entry[2], &w);
		    }
		  weight_lookup.entries[weight_lookup.count].weight = w;
		  weight_lookup.count++;
		}
	    }
	}
      sort_weight_lookup (&weight_lookup);
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGPRW02",
	  "GRAPH_PAGERANK_WEIGHTED: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* Through the shared whole-graph driver: one pass per (snapshot,
   * parameters, weights) instead of one per row. */
  {
    vgraph_batch_result_t br;
    double score = 0.0;
    ctx.weight_lookup = &weight_lookup;
    gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_pagerank_w, &br);
    if (gerr != GRAPH_OK)
      {
	bool no_ws = (GRAPH_ERR_OUT_OF_MEMORY == gerr && !ctx.workspace);
	size_t need = no_ws ? graph_algo_pagerank_workspace_size (ctx.snapshot) : 0;
	vgraph_payload_release (&br);
	free_weight_lookup (&weight_lookup);
	cleanup_algo_context (&ctx);
	if (!*err_ret)
	  {
	    if (no_ws)
	      vgraph_workspace_error (err_ret, "GRAPH_PAGERANK_WEIGHTED", "VGPRW03", need);
	    else
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGPRW05",
		  "GRAPH_PAGERANK_WEIGHTED: algorithm failed: %s", graph_error_string (gerr));
	  }
	return NULL;
      }
    vgraph_payload_double (&br, ctx.snapshot, node_id, &score);
    vgraph_payload_release (&br);
    free_weight_lookup (&weight_lookup);
    cleanup_algo_context (&ctx);
    return box_double (score);
  }
}

/* ============================================================================
 * BIF: GRAPH_BETWEENNESS_WEIGHTED
 *
 * SQL: GRAPH_BETWEENNESS_WEIGHTED(node_iri, graph_iri, predicate_iri, weight_arg)
 * weight_arg: Either a SQL VECTOR of [subject, object, weight] triples,
 *             OR an IRI ID of a weight predicate to read from RDF reification.
 * Returns: DOUBLE - weighted betweenness centrality score
 * ============================================================================ */

static caddr_t
bif_graph_betweenness_weighted (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_BETWEENNESS_WEIGHTED");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_BETWEENNESS_WEIGHTED") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_BETWEENNESS_WEIGHTED") : NULL;
  caddr_t weight_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_BETWEENNESS_WEIGHTED") : NULL;
  /* normalized and directed, in the same sense and the same order as
   * GRAPH_BETWEENNESS's -- and, importantly, defaulted the same way:
   * absent means GRAPH_BETWEENNESS_DEFAULT, which has both true.
   *
   * Not zero.  The unweighted BIF looks like it defaults them to 0, but
   * those locals are parsed for validation and then discarded -- it is a
   * whole-graph algorithm, and vgraph_batch_betweenness_compute re-reads
   * the arguments, starting from GRAPH_BETWEENNESS_DEFAULT and
   * overriding only what was actually passed.  Defaulting to 0 here
   * would make the weighted and unweighted forms disagree, which is the
   * opposite of the point.  (Closeness genuinely does default to 0: it
   * is not a whole-graph algorithm and has no such callback.) */
  /* nargs: the optional arguments are re-read by the compute callback. */

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGBW01", "GRAPH_BETWEENNESS_WEIGHTED: node argument is NULL");
      return NULL;
    }

  graph_node_id_t node_id = vgraph_node_to_id_ex (node_arg, qst);
  if (node_id == GRAPH_NODE_ID_INVALID)
    {
      return box_double (0.0);
    }

  weight_lookup_t weight_lookup = { 0 };
  graph_error_t wlerr = build_weight_lookup_unified (qst, weight_arg, graph_arg, &weight_lookup);
  if (wlerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGBW04",
	  "GRAPH_BETWEENNESS_WEIGHTED: failed to load weights: %s", vgraph_load_reason (wlerr, qst));
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGBW02",
	  "GRAPH_BETWEENNESS_WEIGHTED: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* Through the shared whole-graph driver, so one Brandes pass serves
   * every row of the query rather than one pass per row.  The weights
   * travel on the context because the compute callback needs them and
   * is reached through a function pointer. */
  {
    vgraph_batch_result_t br;
    double score = 0.0;
    ctx.weight_lookup = &weight_lookup;
    gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_betweenness_w, &br);
    if (gerr != GRAPH_OK)
      {
	bool no_ws = (GRAPH_ERR_OUT_OF_MEMORY == gerr && !ctx.workspace);
	size_t need = no_ws ? graph_algo_betweenness_workspace_size (ctx.snapshot) : 0;
	vgraph_payload_release (&br);
	free_weight_lookup (&weight_lookup);
	cleanup_algo_context (&ctx);
	if (!*err_ret)
	  {
	    if (no_ws)
	      vgraph_workspace_error (err_ret, "GRAPH_BETWEENNESS_WEIGHTED", "VGBW03", need);
	    else
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGBW04",
		  "GRAPH_BETWEENNESS_WEIGHTED: algorithm failed: %s", graph_error_string (gerr));
	  }
	return NULL;
      }
    vgraph_payload_double (&br, ctx.snapshot, node_id, &score);
    vgraph_payload_release (&br);
    free_weight_lookup (&weight_lookup);
    cleanup_algo_context (&ctx);
    return box_double (score);
  }
}

/* ============================================================================
 * BIF: GRAPH_CLOSENESS_WEIGHTED
 *
 * SQL: GRAPH_CLOSENESS_WEIGHTED(node_iri, graph_iri, predicate_iri, weight_arg)
 * weight_arg: Either a SQL VECTOR of [subject, object, weight] triples,
 *             OR an IRI ID of a weight predicate to read from RDF reification.
 * Returns: DOUBLE - weighted closeness centrality score
 * ============================================================================ */

static caddr_t
bif_graph_closeness_weighted (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_CLOSENESS_WEIGHTED");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_CLOSENESS_WEIGHTED") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_CLOSENESS_WEIGHTED") : NULL;
  caddr_t weight_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_CLOSENESS_WEIGHTED") : NULL;
  /* normalized: 0=raw (default), 1=normalized -- the same argument, in
   * the same sense and with the same default, as GRAPH_CLOSENESS's.
   * This used to pass NULL params and so ran on GRAPH_CLOSENESS_DEFAULT,
   * whose .normalized is true.  The unweighted BIF overrides that to 0,
   * so the two halves of one measure disagreed by a factor of
   * reached/(n-1) with no way to say which you wanted: on a graph whose
   * edges all weigh 1, where the two must return the same number, they
   * did not. */
  int normalized = BOX_ELEMENTS (args) > 4 ? (int) bif_long_arg (qst, args, 4, "GRAPH_CLOSENESS_WEIGHTED") : 0;
  /* direction: 0=outgoing (default), 1=incoming, 2=both */
  graph_direction_t cdir = GRAPH_DIR_OUTGOING;
  if (BOX_ELEMENTS (args) > 5 &&
      vgraph_direction_arg (bif_arg (qst, args, 5, "GRAPH_CLOSENESS_WEIGHTED"), VGRAPH_DIRENC_TRAVERSAL, GRAPH_DIR_OUTGOING, &cdir))
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGCLW06",
	  "GRAPH_CLOSENESS_WEIGHTED: direction must be 0 or 'out', 1 or 'in', 2 or 'both'");
      return NULL;
    }

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGCW01", "GRAPH_CLOSENESS_WEIGHTED: node argument is NULL");
      return NULL;
    }

  graph_node_id_t node_id = vgraph_node_to_id_ex (node_arg, qst);
  if (node_id == GRAPH_NODE_ID_INVALID)
    {
      return box_double (0.0);
    }

  weight_lookup_t weight_lookup = { 0 };
  graph_error_t wlerr = build_weight_lookup_unified (qst, weight_arg, graph_arg, &weight_lookup);
  if (wlerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGCW04",
	  "GRAPH_CLOSENESS_WEIGHTED: failed to load weights: %s", vgraph_load_reason (wlerr, qst));
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGCW02",
	  "GRAPH_CLOSENESS_WEIGHTED: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  size_t ws_size = graph_algo_closeness_workspace_size (ctx.snapshot);
  ctx.workspace = vgraph_get_workspace (ws_size);
  if (!ctx.workspace)
    {
      cleanup_algo_context (&ctx);
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, "VGCW03",
	  "GRAPH_CLOSENESS_WEIGHTED: workspace of %lu bytes exceeds [Graph] MaxWorkspace (%lu bytes)",
	  (unsigned long) ws_size, (unsigned long) vgraph_workspace_limit ());
      return NULL;
    }

  graph_closeness_params_t params = GRAPH_CLOSENESS_DEFAULT;
  params.normalized = (normalized != 0);
  params.direction = cdir;

  graph_closeness_result_t result;
  gerr = graph_algo_closeness_weighted (ctx.snapshot, &params, NULL, weighted_edge_lookup, &weight_lookup, ctx.workspace, &result);

  double score = 0.0;
  if (gerr == GRAPH_OK)
    {
      uint64_t idx = find_node_index (ctx.snapshot, node_id);
      if (idx < result.node_count)
	{
	  score = result.scores[idx];
	}
    }

  free_weight_lookup (&weight_lookup);
  cleanup_algo_context (&ctx);
  return box_double (score);
}

/* ============================================================================
 * BIF: GRAPH_EIGENVECTOR_WEIGHTED
 *
 * SQL: GRAPH_EIGENVECTOR_WEIGHTED(node_iri, graph_iri, predicate_iri, weight_arg)
 * weight_arg: Either a SQL VECTOR of [subject, object, weight] triples,
 *             OR an IRI ID of a weight predicate to read from RDF reification.
 * Returns: DOUBLE - weighted eigenvector centrality score
 * ============================================================================ */

static caddr_t
bif_graph_eigenvector_weighted (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_EIGENVECTOR_WEIGHTED");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_EIGENVECTOR_WEIGHTED") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_EIGENVECTOR_WEIGHTED") : NULL;
  caddr_t weight_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_EIGENVECTOR_WEIGHTED") : NULL;
  /* Dropped the same way pagerank's were; see the note there. */
  graph_eigenvector_params_t ev_params = GRAPH_EIGENVECTOR_DEFAULT;
  int nargs_ev = BOX_ELEMENTS (args);
  if (nargs_ev > 4)
    {
      caddr_t a = bif_arg (qst, args, 4, "GRAPH_EIGENVECTOR_WEIGHTED");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  int64_t mi = unbox (a);
	  if (mi < 1 || mi > 100000)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGEW06",
		  "GRAPH_EIGENVECTOR_WEIGHTED: max_iter must be in [1,100000], got %ld", (long) mi);
	      return NULL;
	    }
	  ev_params.max_iterations = (int) mi;
	}
    }
  if (nargs_ev > 5)
    {
      caddr_t a = bif_arg (qst, args, 5, "GRAPH_EIGENVECTOR_WEIGHTED");
      if (a && DV_TYPE_OF (a) != DV_DB_NULL)
	{
	  ev_params.epsilon = vgraph_box_to_double (a);
	  if (ev_params.epsilon <= 0.0 || ev_params.epsilon >= 1.0)
	    {
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGEW07",
		  "GRAPH_EIGENVECTOR_WEIGHTED: tolerance must be in (0,1), got %g", ev_params.epsilon);
	      return NULL;
	    }
	}
    }

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGEW01", "GRAPH_EIGENVECTOR_WEIGHTED: node argument is NULL");
      return NULL;
    }

  graph_node_id_t node_id = vgraph_node_to_id_ex (node_arg, qst);
  if (node_id == GRAPH_NODE_ID_INVALID)
    {
      return box_double (0.0);
    }

  weight_lookup_t weight_lookup = { 0 };
  graph_error_t wlerr = build_weight_lookup_unified (qst, weight_arg, graph_arg, &weight_lookup);
  if (wlerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGEW04",
	  "GRAPH_EIGENVECTOR_WEIGHTED: failed to load weights: %s", vgraph_load_reason (wlerr, qst));
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGEW02",
	  "GRAPH_EIGENVECTOR_WEIGHTED: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  size_t ws_size = graph_algo_eigenvector_workspace_size (ctx.snapshot);
  ctx.workspace = vgraph_get_workspace (ws_size);
  if (!ctx.workspace)
    {
      cleanup_algo_context (&ctx);
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, "VGEW03",
	  "GRAPH_EIGENVECTOR_WEIGHTED: workspace of %lu bytes exceeds [Graph] MaxWorkspace (%lu bytes)",
	  (unsigned long) ws_size, (unsigned long) vgraph_workspace_limit ());
      return NULL;
    }

  /* Through the shared whole-graph driver: one pass per (snapshot,
   * parameters, weights) instead of one per row. */
  {
    vgraph_batch_result_t br;
    double score = 0.0;
    ctx.weight_lookup = &weight_lookup;
    gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_eigenvector_w, &br);
    if (gerr != GRAPH_OK)
      {
	bool no_ws = (GRAPH_ERR_OUT_OF_MEMORY == gerr && !ctx.workspace);
	size_t need = no_ws ? graph_algo_eigenvector_workspace_size (ctx.snapshot) : 0;
	vgraph_payload_release (&br);
	free_weight_lookup (&weight_lookup);
	cleanup_algo_context (&ctx);
	if (!*err_ret)
	  {
	    if (no_ws)
	      vgraph_workspace_error (err_ret, "GRAPH_EIGENVECTOR_WEIGHTED", "VGEW03", need);
	    else
	      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGEW05",
		  "GRAPH_EIGENVECTOR_WEIGHTED: algorithm failed: %s", graph_error_string (gerr));
	  }
	return NULL;
      }
    vgraph_payload_double (&br, ctx.snapshot, node_id, &score);
    vgraph_payload_release (&br);
    free_weight_lookup (&weight_lookup);
    cleanup_algo_context (&ctx);
    return box_double (score);
  }
}

/* ============================================================================
 * BIF: GRAPH_DEGREE_W_SPARQL
 *
 * SQL: GRAPH_DEGREE_W_SPARQL(node_iri, graph_iri, predicate_iri, weight_predicate_iri)
 * Returns: DOUBLE PRECISION - weighted degree (sum of edge weights)
 *
 * Builds a weight lookup from RDF reification patterns in the graph:
 *   - W3C reification: ?stmt rdf:subject ?s; rdf:object ?o; <weight_pred> ?w
 *   - RDF 1.2 triple terms: << ?s ?p ?o >> <weight_pred> ?w
 *   - N-ary: ?stmt rdf:subject ?s; rdf:object ?o; <weight_pred> ?w
 *
 * The weight_predicate_iri is the predicate used to store the weight value
 * on the reified statement (e.g. iri_to_id(':weight'), iri_to_id(':hasScore')).
 * ============================================================================ */

static caddr_t
bif_graph_degree_w_sparql (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_DEGREE_W_SPARQL");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_DEGREE_W_SPARQL") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_DEGREE_W_SPARQL") : NULL;
  caddr_t weight_pred_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_DEGREE_W_SPARQL") : NULL;
  caddr_t dir_arg = BOX_ELEMENTS (args) > 4 ? bif_arg (qst, args, 4, "GRAPH_DEGREE_W_SPARQL") : NULL;
  int dws_normalized = BOX_ELEMENTS (args) > 5 ? (int) bif_long_arg (qst, args, 5, "GRAPH_DEGREE_W_SPARQL") : 0;

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGDWS01", "GRAPH_DEGREE_W_SPARQL: node argument is NULL");
      return NULL;
    }

  graph_node_id_t node_id = vgraph_node_to_id_ex (node_arg, qst);
  if (node_id == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGDWS02", "GRAPH_DEGREE_W_SPARQL: invalid node IRI");
      return NULL;
    }

  /* Resolve weight predicate IRI.  One the store has never seen -- a
   * typo, usually -- resolves to 0 and is passed on as such: the weight
   * builder refuses it as matching no edges, or reads the column of a
   * table-sourced graph, which needs no predicate.  Calling it
   * "required" named the wrong problem. */
  graph_iri_id_t weight_pred_iri = 0;
  if (!weight_pred_arg || DV_TYPE_OF (weight_pred_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGDWS03",
	  "GRAPH_DEGREE_W_SPARQL: weight predicate IRI is required");
      return NULL;
    }
  weight_pred_iri = vgraph_iri_to_id_ex (weight_pred_arg, qst);

  /* Parse direction: 0=BOTH (default), 1=INCOMING, 2=OUTGOING */
  int direction = 0;
  {
    graph_direction_t gd;
    if (vgraph_direction_arg (dir_arg, VGRAPH_DIRENC_DEGREE, GRAPH_DIR_BOTH, &gd))
      {
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGDWS06",
	    "GRAPH_DEGREE_W_SPARQL: direction must be 0 or 'both', 1 or 'in', 2 or 'out'");
	return NULL;
      }
    /* back into this BIF's own integers, which the code below maps again */
    direction = (GRAPH_DIR_INCOMING == gd) ? 1 : (GRAPH_DIR_OUTGOING == gd) ? 2 : 0;
  }

  /* Resolve graph IRI */
  graph_iri_id_t graph_iri = 0;
  if (graph_arg && DV_TYPE_OF (graph_arg) != DV_DB_NULL)
    {
      graph_iri = vgraph_iri_to_id_ex (graph_arg, qst);
    }

  /* Build weight lookup from reification patterns in the graph */
  weight_lookup_t weight_lookup = { 0 };
  graph_error_t gerr = vgraph_weight_lookup_from_edges (qst, graph_iri, &weight_lookup)
      ? GRAPH_OK : build_weight_lookup_from_graph (qst, graph_iri,
      weight_pred_iri, &weight_lookup);
  if (gerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGDWS04",
	  "GRAPH_DEGREE_W_SPARQL: failed to load weights: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* Set up algorithm context */
  algo_context_t ctx;
  gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGDWS05",
	  "GRAPH_DEGREE_W_SPARQL: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* Sum of the incident edge weights.  Non-positive weights are ignored,
   * matching another engine's behaviour.
   * direction: 0=both, 1=incoming, 2=outgoing */
  double weighted_degree = vgraph_weighted_degree_sum (ctx.snapshot, node_id, direction, true,
      &weight_lookup);
  weighted_degree = vgraph_normalize_by_order (weighted_degree, ctx.snapshot, dws_normalized);

  /* No delta pass here: the neighbour iterator walks the delta chain as
   * its third phase, so a second loop over it would count every pending
   * addition twice. */

  cleanup_algo_context (&ctx);
  free_weight_lookup (&weight_lookup);
  return box_double (weighted_degree);
}

/* ============================================================================
 * BIF: GRAPH_DEGREE_WEIGHTED (legacy - kept for compatibility)
 * 
 * SQL: GRAPH_DEGREE_WEIGHTED(node_iri, graph_iri, predicate_iri, weight_vector)
 * Returns: DOUBLE PRECISION - weighted degree (sum of edge weights)
 * Note: This version has IRI_ID boxing issues, use GRAPH_DEGREE_W_SPARQL instead
 * ============================================================================ */

static caddr_t
bif_graph_degree_weighted (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_DEGREE_WEIGHTED");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_DEGREE_WEIGHTED") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_DEGREE_WEIGHTED") : NULL;
  caddr_t weight_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_DEGREE_WEIGHTED") : NULL;
  int dw_normalized = BOX_ELEMENTS (args) > 4 ? (int) bif_long_arg (qst, args, 4, "GRAPH_DEGREE_WEIGHTED") : 0;

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGDW01", "GRAPH_DEGREE_WEIGHTED: node argument is NULL");
      return NULL;
    }

  graph_node_id_t node_id = vgraph_node_to_id_ex (node_arg, qst);
  if (node_id == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGDW02", "GRAPH_DEGREE_WEIGHTED: invalid node IRI");
      return NULL;
    }

  /* Build weight lookup table (IRI ID for reification, or VECTOR) */
  weight_lookup_t weight_lookup = { 0 };
  graph_error_t wlerr = build_weight_lookup_unified (qst, weight_arg, graph_arg, &weight_lookup);
  if (wlerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGDW04",
	  "GRAPH_DEGREE_WEIGHTED: failed to load weights: %s", vgraph_load_reason (wlerr, qst));
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      free_weight_lookup (&weight_lookup);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGDW03",
	  "GRAPH_DEGREE_WEIGHTED: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* Sum of the incident edge weights, both directions, every weight
   * counted whatever its sign -- which is the one behaviour that
   * separates this from GRAPH_DEGREE_W_SPARQL.  The iterator covers the
   * delta chain, so there is no separate pass over pending additions. */
  double weighted_degree = vgraph_weighted_degree_sum (ctx.snapshot, node_id, 0, false,
      &weight_lookup);
  weighted_degree = vgraph_normalize_by_order (weighted_degree, ctx.snapshot, dw_normalized);

  free_weight_lookup (&weight_lookup);
  cleanup_algo_context (&ctx);
  return box_double (weighted_degree);
}

/* ============================================================================
 * BIF: GRAPH_BFS
 * 
 * SQL: GRAPH_BFS(source, target, graph, predicate, direction)
 *      GRAPH_DFS(source, target, graph, predicate, direction)
 * Returns: INTEGER - BFS the distance (-1 if unreachable), DFS 1 or 0
 * ============================================================================ */

/* Breadth-first and depth-first search over one cached traversal.
 *
 * GRAPH_DFS returns reachability and a reached-node count; neither
 * depends on the order the traversal visits in, so there is nothing for
 * a second, depth-first pass to compute that this one has not already.
 * Running both would mean two whole-graph traversals per snapshot where
 * one answers both questions, and they would share no cache entry. */
static caddr_t
vgraph_reach_bif (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, const char *fname, const char *const *code, int as_reach)
{
  caddr_t source_arg = bif_arg (qst, args, 0, (char *) fname);
  caddr_t target_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, (char *) fname) : NULL;
  caddr_t graph_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, (char *) fname) : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, (char *) fname) : NULL;
  /* Optional direction: 0=outgoing (default), 1=incoming, 2=both */
  int direction = 0;
  if (BOX_ELEMENTS (args) > 4)
    {
      graph_direction_t gd;
      if (vgraph_direction_arg (bif_arg (qst, args, 4, (char *) fname), VGRAPH_DIRENC_TRAVERSAL, GRAPH_DIR_OUTGOING, &gd))
	{
	  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, (char *) code[5],
	      "%s: direction must be 0 or 'out', 1 or 'in', 2 or 'both'", fname);
	  return NULL;
	}
      direction = (int) gd;
    }

  if (!source_arg || DV_TYPE_OF (source_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, (char *) code[0], "%s: source argument is NULL", fname);
      return NULL;
    }

  graph_node_id_t source_id = vgraph_node_to_id_ex (source_arg, qst);
  if (source_id == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, (char *) code[1], "%s: invalid source IRI", fname);
      return NULL;
    }

  graph_node_id_t target_id = GRAPH_NODE_ID_INVALID;
  if (target_arg && DV_TYPE_OF (target_arg) != DV_DB_NULL)
    {
      target_id = vgraph_node_to_id_ex (target_arg, qst);
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, (char *) code[2],
	  "%s: failed to load graph: %s", fname, vgraph_load_reason (gerr, qst));
      return NULL;
    }

  /* One traversal per (snapshot, source, direction), read out of the
   * whole-graph result cache; the target is an index into it. */
  ctx.src_node = source_id;

  vgraph_batch_result_t br;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_bfs, &br);
  if (gerr != GRAPH_OK)
    {
      bool no_ws = (GRAPH_ERR_OUT_OF_MEMORY == gerr && !ctx.workspace);
      size_t need = no_ws ? graph_algo_bfs_workspace_size (ctx.snapshot) : 0;
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	{
	  if (no_ws)
	    vgraph_workspace_error (err_ret, (char *) fname, (char *) code[3], need);
	  else
	    *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, (char *) code[4], "%s: algorithm failed", fname);
	}
      return NULL;
    }

  int64_t distance = -1;
  if (target_id != GRAPH_NODE_ID_INVALID)
    {
      uint64_t d = 0;
      if (vgraph_payload_int (&br, ctx.snapshot, target_id, &d) && d != UINT64_MAX)
	distance = (int64_t) d;
    }
  else
    {
      /* No target: the number of nodes the source reaches, which is the
       * count of finite entries in the same cached distance vector. */
      const uint64_t *dist = (const uint64_t *) br.payload;
      uint64_t i, reached = 0;
      for (i = 0; dist && i < br.node_count; i++)
	if (dist[i] != UINT64_MAX)
	  reached++;
      distance = (int64_t) reached;
    }

  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);
  /* Depth-first search asks whether the target is reachable, not how
     far away it is.  Reachability does not depend on the order a
     traversal visits in, so the two read the same cached distance
     vector and differ only here.  With no target both return the
     number of nodes reached, which is order-independent as well. */
  if (as_reach && target_id != GRAPH_NODE_ID_INVALID)
    return box_num (distance >= 0 ? 1 : 0);
  return box_num (distance);
}

static const char *const vgraph_bfs_codes[] = { "VGBFS01", "VGBFS02", "VGBFS03", "VGBFS04", "VGBFS05", "VGBFS06" };
static const char *const vgraph_dfs_codes[] = { "VGDFS01", "VGDFS02", "VGDFS03", "VGDFS04", "VGDFS05", "VGDFS06" };

static caddr_t
bif_graph_bfs (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  return vgraph_reach_bif (qst, err_ret, args, "GRAPH_BFS", vgraph_bfs_codes, 0);
}

static caddr_t
bif_graph_dfs (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  return vgraph_reach_bif (qst, err_ret, args, "GRAPH_DFS", vgraph_dfs_codes, 1);
}

/* ============================================================================
 * BIF: GRAPH_WCC
 * 
 * SQL: GRAPH_WCC(node_iri, graph_iri, predicate_iri)
 * Returns: INTEGER - weakly connected component ID for the node
 * ============================================================================ */

static caddr_t
bif_graph_wcc (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_WCC");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_WCC") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_WCC") : NULL;

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGWCC01", "GRAPH_WCC: node argument is NULL");
      return NULL;
    }

  graph_node_id_t node_id = vgraph_node_to_id_ex (node_arg, qst);
  if (node_id == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGWCC02", "GRAPH_WCC: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGWCC03",
	  "GRAPH_WCC: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  vgraph_batch_result_t br;
  uint64_t comp_value = 0;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_wcc, &br);
  if (gerr != GRAPH_OK)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGWCC05", "GRAPH_WCC: algorithm failed");
      return NULL;
    }

  int64_t component_id = -1;
  if (vgraph_payload_int (&br, ctx.snapshot, node_id, &comp_value))
    component_id = (int64_t) comp_value;
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);
  return box_num (component_id);
}

/* ============================================================================
 * BIF: GRAPH_WCC_COUNT
 * 
 * SQL: GRAPH_WCC_COUNT(graph_iri, predicate_iri)
 * Returns: INTEGER - number of weakly connected components
 * ============================================================================ */

static caddr_t
bif_graph_wcc_count (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t graph_arg = BOX_ELEMENTS (args) > 0 ? bif_arg (qst, args, 0, "GRAPH_WCC_COUNT") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_WCC_COUNT") : NULL;

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGWCC11",
	  "GRAPH_WCC_COUNT: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  size_t ws_size = graph_algo_wcc_workspace_size (ctx.snapshot);
  ctx.workspace = vgraph_get_workspace (ws_size);
  if (!ctx.workspace)
    {
      cleanup_algo_context (&ctx);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, "VGWCC12",
	  "GRAPH_WCC_COUNT: workspace of %lu bytes exceeds [Graph] MaxWorkspace (%lu bytes)",
	  (unsigned long) ws_size, (unsigned long) vgraph_workspace_limit ());
      return NULL;
    }

  graph_wcc_result_t result;
  gerr = graph_algo_wcc (ctx.snapshot, NULL, ctx.workspace, &result);

  if (gerr != GRAPH_OK)
    {
      cleanup_algo_context (&ctx);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGWCC13", "GRAPH_WCC_COUNT: algorithm failed");
      return NULL;
    }

  int64_t count = (int64_t) result.component_count;
  cleanup_algo_context (&ctx);
  return box_num (count);
}

/* ============================================================================
 * BIF: GRAPH_SCC
 * 
 * SQL: GRAPH_SCC(node_iri, graph_iri, predicate_iri)
 * Returns: INTEGER - strongly connected component ID for the node
 * ============================================================================ */

static caddr_t
bif_graph_scc (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t node_arg = bif_arg (qst, args, 0, "GRAPH_SCC");
  caddr_t graph_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_SCC") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "GRAPH_SCC") : NULL;

  if (!node_arg || DV_TYPE_OF (node_arg) == DV_DB_NULL)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_NULL_ARG, "VGSCC01", "GRAPH_SCC: node argument is NULL");
      return NULL;
    }

  graph_node_id_t node_id = vgraph_node_to_id_ex (node_arg, qst);
  if (node_id == GRAPH_NODE_ID_INVALID)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGSCC02", "GRAPH_SCC: invalid node IRI");
      return NULL;
    }

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGSCC03",
	  "GRAPH_SCC: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  vgraph_batch_result_t br;
  uint64_t comp_value = 0;
  gerr = vgraph_scalar_whole_graph (qst, err_ret, args, &ctx, &vgraph_wg_scc, &br);
  if (gerr != GRAPH_OK)
    {
      vgraph_payload_release (&br);
      cleanup_algo_context (&ctx);
      if (!*err_ret)
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGSCC05", "GRAPH_SCC: algorithm failed");
      return NULL;
    }

  int64_t component_id = -1;
  if (vgraph_payload_int (&br, ctx.snapshot, node_id, &comp_value))
    component_id = (int64_t) comp_value;
  vgraph_payload_release (&br);
  cleanup_algo_context (&ctx);
  return box_num (component_id);
}

/* ============================================================================
 * BIF: GRAPH_SCC_COUNT
 * 
 * SQL: GRAPH_SCC_COUNT(graph_iri, predicate_iri)
 * Returns: INTEGER - number of strongly connected components
 * ============================================================================ */

static caddr_t
bif_graph_scc_count (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t graph_arg = BOX_ELEMENTS (args) > 0 ? bif_arg (qst, args, 0, "GRAPH_SCC_COUNT") : NULL;
  caddr_t pred_arg = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, "GRAPH_SCC_COUNT") : NULL;

  algo_context_t ctx;
  graph_error_t gerr = setup_algo_context (qst, graph_arg, pred_arg, &ctx);
  if (gerr != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_SCOPE_ERROR, "VGSCC11",
	  "GRAPH_SCC_COUNT: failed to load graph: %s", vgraph_load_reason (gerr, qst));
      return NULL;
    }

  size_t ws_size = graph_algo_scc_workspace_size (ctx.snapshot);
  ctx.workspace = vgraph_get_workspace (ws_size);
  if (!ctx.workspace)
    {
      cleanup_algo_context (&ctx);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_MEMORY, "VGSCC12",
	  "GRAPH_SCC_COUNT: workspace of %lu bytes exceeds [Graph] MaxWorkspace (%lu bytes)",
	  (unsigned long) ws_size, (unsigned long) vgraph_workspace_limit ());
      return NULL;
    }

  graph_scc_result_t result;
  gerr = graph_algo_scc (ctx.snapshot, NULL, ctx.workspace, &result);

  if (gerr != GRAPH_OK)
    {
      cleanup_algo_context (&ctx);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGSCC13", "GRAPH_SCC_COUNT: algorithm failed");
      return NULL;
    }

  int64_t count = (int64_t) result.component_count;
  cleanup_algo_context (&ctx);
  return box_num (count);
}

/* ============================================================================
 * BIF: GRAPH_SET_LIMIT
 *
 * SQL: GRAPH_SET_LIMIT (name, value)
 *
 * Adjust one of the graph analytics resource limits without restarting.
 * The INI file still sets the boot-time value; this is for an operator who
 * needs to tighten (or relax) a limit on a running server, and it is what
 * makes the limits testable.  DBA only.  Returns the value actually in
 * effect after clamping.
 * ============================================================================ */

/* ============================================================================
 * BIF: GRAPH_LOAD_TABLE
 *
 * SQL: GRAPH_LOAD_TABLE (graph_iri, pred_iri, table_name [, weight_col])
 *
 * Load a graph's edges from `SELECT S, O FROM <table>` instead of from
 * RDF_QUAD, and remember the table so a later cache miss reloads from it.
 *
 * With a weight column named, the weighted algorithms take their weights
 * from that column instead of scanning RDF for a reified weight, and the
 * weight predicate they are called with names nothing.  The column is read
 * on the first weighted call rather than during the load: it is a separate
 * scan, but a cheap one, and it keeps the weights on exactly the lifecycle
 * RDF weights are on -- built lazily, shared between calls, keyed on the
 * cache generation, and rebuilt after any commit.
 *
 * Why this exists, measured on 4,000,000 real edges: the same edges take
 * 4.85 s into a SQL table with the stock vectored CSV loader and 57.9 s
 * through rdf_loader_run.  Not because RDF is slow -- unweighted, those
 * edges load faster per row as triples than as table rows -- but because
 * a weighted edge is three rows in RDF and one in a table.
 *
 * Freshness works the same way it does for an RDF-sourced graph, which is
 * the point: the loaded graph is cached, any write to the database retires
 * the cache entry, and the next algorithm call re-reads the source.  So a
 * change to the table is visible on the next call without anything being
 * called again -- and calling this again forces the read and reports the
 * edge count, which is the only reason to.
 *
 * That re-read is why the registry above exists.  Without it the miss
 * would look for the graph in RDF_QUAD, not find it, and return an empty
 * graph rather than an error.
 * ============================================================================ */

static caddr_t
bif_graph_load_table (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t graph_arg = bif_arg (qst, args, 0, "GRAPH_LOAD_TABLE");
  caddr_t pred_arg = bif_arg (qst, args, 1, "GRAPH_LOAD_TABLE");
  caddr_t table = bif_string_arg (qst, args, 2, "GRAPH_LOAD_TABLE");
  caddr_t wcol_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "GRAPH_LOAD_TABLE") : NULL;
  const char *wcol = NULL;
  graph_iri_id_t graph_id;
  graph_pred_id_t pred_id;
  quad_store_t *store = NULL;
  quad_store_config_t store_config = QUAD_STORE_CONFIG_DEFAULT;
  graph_t *graph = NULL;
  graph_snapshot_t *snapshot = NULL;
  gcache_handle_t handle;
  uint64_t loaded = 0;
  graph_error_t err;

  /* The table registry is shared by every session, so pointing a graph
   * IRI at a table is administration, not a query -- before any argument
   * fetch that mints an IRI.  GRAPH_LOAD_TABLE is also on the SPARQL
   * unsafe-bif denylist, so the anonymous endpoint cannot reach it. */
  sec_check_dba ((query_instance_t *) qst, "GRAPH_LOAD_TABLE");

  graph_id = (graph_iri_id_t) vgraph_iri_to_id_create (graph_arg, qst);
  if (!graph_id || GRAPH_NODE_ID_INVALID == graph_id)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLDT01", "GRAPH_LOAD_TABLE: invalid graph IRI");
      return NULL;
    }
  /* Minted if unseen: the predicate names an edge kind that lives only
   * in the table, so it has never been an RDF term. */
  pred_id = (graph_pred_id_t) vgraph_iri_to_id_create (pred_arg, qst);
  if (GRAPH_PRED_ID_INVALID == pred_id || !pred_id)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLDT02", "GRAPH_LOAD_TABLE: invalid predicate IRI");
      return NULL;
    }

  if (wcol_arg && DV_TYPE_OF (wcol_arg) != DV_DB_NULL)
    {
      if (!DV_STRINGP (wcol_arg))
	{
	  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLDT07",
	      "GRAPH_LOAD_TABLE: weight column must be a string");
	  return NULL;
	}
      wcol = (const char *) wcol_arg;
      /* Refused here rather than at the first weighted call: a name that
       * cannot be read is a mistake in this statement, and reporting it
       * two calls later would point at the wrong thing. */
      if (!wcol[0] || !vgraph_table_name_ok (wcol) || strchr (wcol, '.'))
	{
	  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLDT08",
	      "GRAPH_LOAD_TABLE: %.100s is not a usable column name", wcol);
	  return NULL;
	}
    }

  /* Analytics readers are let in by SPARQL_SELECT (see
   * vgraph_graph_check_read), so a source table has to be readable by that
   * role, as RDF_QUAD is.  A table that does not resolve is left to the
   * load, which reports it. */
  {
    dbe_table_t *tb = wi_inst.wi_schema ? sch_name_to_table (wi_inst.wi_schema, table) : NULL;
    user_t *role = sec_name_to_user ("SPARQL_SELECT");
    if (tb && (!role || !sec_tb_check (tb, role->usr_id, role->usr_id, GR_SELECT)))
      {
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLDT09",
	    "GRAPH_LOAD_TABLE: %.200s must be granted SELECT to SPARQL_SELECT", table);
	return NULL;
      }
  }

  /* Retire anything cached under this graph IRI before installing the
   * new contents, so a reader cannot be served the previous load.  The
   * generation bump also retires any weight table built from a previous
   * registration of this graph, which is what stops an old column's
   * weights being served for a new one. */
  gcache_invalidate (graph_id);
  gcache_increment_generation ();

  store_config.allocator = vgraph_core_allocator;
  err = quad_store_create (&store_config, &store);
  if (err != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDT03", "GRAPH_LOAD_TABLE: %s", graph_error_string (err));
      return NULL;
    }

  /* Runs on the caller's own connection, so the caller's SELECT
   * permission on the table is the permission check.  A user who may
   * not read the table gets the SQL error for that, here, at load
   * time. */
  err = vgraph_load_from_table (qst, store, table, graph_id, pred_id, &loaded);
  if (err != GRAPH_OK)
    {
      quad_store_destroy (store);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDT04",
	  "GRAPH_LOAD_TABLE: failed to read %.200s: %s", table, vgraph_load_reason (err, qst));
      return NULL;
    }

  err = quad_store_get_graph (store, graph_id, false, &graph);
  if (err != GRAPH_OK || !graph)
    {
      quad_store_destroy (store);
      /* An empty table is not an error; it is an empty graph.  But there
       * is no graph object to cache, so say so and let the next call
       * build one. */
      vgraph_table_src_set (graph_id, table, wcol, pred_id);
      return box_num (0);
    }

  err = graph_snapshot_create (graph, &snapshot);
  if (err != GRAPH_OK)
    {
      quad_store_destroy (store);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDT05", "GRAPH_LOAD_TABLE: %s", graph_error_string (err));
      return NULL;
    }
  if (vgraph_snapshot_over_limit (snapshot))
    {
      graph_snapshot_release (snapshot);
      quad_store_destroy (store);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDT06",
	  "GRAPH_LOAD_TABLE: graph exceeds [Graph] MaxNodes or " "[Graph] MaxTriples");
      return NULL;
    }

  vgraph_table_src_set (graph_id, table, wcol, pred_id);

  if (gcache_put (graph_id, pred_id, vgraph_transaction_epoch (qst), store, graph, snapshot, &handle) == GRAPH_OK)
    {
      gcache_release (&handle);
    }
  else
    {
      /* Not cacheable is not fatal: the registry above means the next
       * call reloads from the same table and gets the same graph. */
      graph_snapshot_release (snapshot);
      quad_store_destroy (store);
    }
  return box_num ((boxint) loaded);
}

/* ============================================================================
 * BIF: GRAPH_LOAD_EDGES
 *
 * SQL: GRAPH_LOAD_EDGES (graph_iri, predicate_iri, edges) RETURNS INTEGER
 *
 * `edges` is a vector of vector(subject, object), or of
 * vector(subject, predicate, object) whose middle element is ignored.
 * Returns the number of edges taken.
 *
 * The graph is private to this connection and written nowhere.  See the
 * registry above for why it is kept, why it is keyed on the session, and
 * why its cache key is not the IRI.
 * ========================================================================= */
static caddr_t
bif_graph_load_edges_int (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, int weighted)
{
  const char *fname = weighted ? "GRAPH_LOAD_EDGES_W" : "GRAPH_LOAD_EDGES";
  caddr_t graph_arg = bif_arg (qst, args, 0, fname);
  caddr_t pred_arg = bif_arg (qst, args, 1, fname);
  caddr_t edges_arg = bif_arg (qst, args, 2, fname);
  double *weights = NULL;
  int bad_what = 0, bad_dtp = 0;
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi ? qi->qi_client : NULL;
  graph_iri_id_t graph_iri, private_id;
  graph_pred_id_t pred_id;
  graph_node_id_t *edges = NULL;
  uint64_t n_edges = 0, loaded = 0;
  int64_t bad_row = -1;
  quad_store_t *store = NULL;
  quad_store_config_t store_config = QUAD_STORE_CONFIG_DEFAULT;
  graph_t *graph = NULL;
  graph_snapshot_t *snapshot = NULL;
  gcache_handle_t handle;
  graph_error_t err;

  if (!cli)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLDE05", "%s: no connection to own the graph", fname);
      return NULL;
    }

  graph_iri = (graph_iri_id_t) vgraph_iri_to_id_create (graph_arg, qst);
  if (!graph_iri || GRAPH_NODE_ID_INVALID == graph_iri)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLDE01", "%s: invalid graph IRI", fname);
      return NULL;
    }
  /* Minted if unseen, like the table form: the predicate names an edge
   * kind that may never have been an RDF term. */
  pred_id = (graph_pred_id_t) vgraph_iri_to_id_create (pred_arg, qst);
  if (GRAPH_PRED_ID_INVALID == pred_id || !pred_id)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLDE02", "%s: invalid predicate IRI", fname);
      return NULL;
    }

  err = vgraph_edges_from_vector (edges_arg, qst, &edges, &n_edges, &bad_row, weighted ? &weights : NULL, &bad_what, &bad_dtp);
  if (err == GRAPH_ERR_CAPACITY_EXCEEDED)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDE06",
	  "%s: %ld edges exceeds [Graph] MaxTriples (%ld)", fname,
	  (long) BOX_ELEMENTS (edges_arg), (long) vgraph_max_graph_triples);
      return NULL;
    }
  if (err != GRAPH_OK)
    {
      if (bad_row >= 0)
	{
	  char why[160];
	  switch (bad_what)
	    {
	    case 1:
	      snprintf (why, sizeof (why), "the subject of edge %ld is not a node IRI (dtp %d)", (long) bad_row, bad_dtp);
	      break;
	    case 2:
	      snprintf (why, sizeof (why), "the object of edge %ld is not a node IRI (dtp %d)", (long) bad_row, bad_dtp);
	      break;
	    case 3:
	      snprintf (why, sizeof (why), "the weight of edge %ld is not a number (dtp %d)", (long) bad_row, bad_dtp);
	      break;
	    default:
	      snprintf (why, sizeof (why), "edge %ld is not %s",
		  (long) bad_row, weighted ? "vector(subject, object, weight)" : "vector(subject, object)");
	    }
	  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLDE03", "%s: %s", fname, why);
	}
      else
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLDE03",
	    weighted
	    ? "%s: edges must be a vector of vector(subject, object, weight)"
	    : "%s: edges must be a vector of vector(subject, object)", fname);
      return NULL;
    }

  /* Installed before the load so that the private id exists to build
   * under, and so that a previous registration of the same name by this
   * session -- and its cached snapshot -- is gone first. */
  private_id = vgraph_edge_src_set (graph_iri, pred_id, cli, edges, n_edges, weights);
  if (!private_id)
    {
      if (edges)
	dk_free (edges, (size_t) n_edges * 2 * sizeof (graph_node_id_t));
      if (weights)
	dk_free (weights, (size_t) n_edges * sizeof (double));
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDE04", "%s: could not register the graph", fname);
      return NULL;
    }

  if (!n_edges)
    return box_num (0);		/* an empty edge list is an empty graph */

  store_config.allocator = vgraph_core_allocator;
  err = quad_store_create (&store_config, &store);
  if (err != GRAPH_OK)
    {
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDE04", "%s: %s", fname, graph_error_string (err));
      return NULL;
    }

  {
    graph_node_id_t *own = NULL;
    uint64_t own_n = 0;
    graph_pred_id_t own_pred = GRAPH_PRED_ID_INVALID;
    if (!vgraph_edge_src_get (private_id, &own, &own_n, &own_pred, NULL))
      {
	quad_store_destroy (store);
	*err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDE04", "%s: the registration went away mid-load", fname);
	return NULL;
      }
    err = vgraph_load_from_edges (store, private_id, own, own_n, own_pred, cli, &loaded);
    dk_free (own, (size_t) own_n * 2 * sizeof (graph_node_id_t));
  }
  if (err != GRAPH_OK)
    {
      quad_store_destroy (store);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDE04", "%s: %s", fname, vgraph_load_reason (err, qst));
      return NULL;
    }

  err = quad_store_get_graph (store, private_id, false, &graph);
  if (err != GRAPH_OK || !graph)
    {
      quad_store_destroy (store);
      return box_num ((boxint) loaded);
    }
  err = graph_snapshot_create (graph, &snapshot);
  if (err != GRAPH_OK)
    {
      quad_store_destroy (store);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDE04", "%s: %s", fname, graph_error_string (err));
      return NULL;
    }
  /* The node bound, which the edge count could not express: two hundred
   * edges may be four hundred nodes. */
  if (vgraph_snapshot_over_limit (snapshot))
    {
      graph_snapshot_release (snapshot);
      quad_store_destroy (store);
      vgraph_edge_src_clear (graph_iri, cli);
      *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_ALGO_ERROR, "VGLDE06",
	  "%s: graph exceeds [Graph] MaxNodes or " "[Graph] MaxTriples", fname);
      return NULL;
    }

  if (gcache_put (private_id, pred_id, vgraph_transaction_epoch (qst), store, graph, snapshot, &handle) == GRAPH_OK)
    {
      gcache_release (&handle);
    }
  else
    {
      /* Not cacheable is not fatal: the registration above means the
       * next call rebuilds from the same edges. */
      graph_snapshot_release (snapshot);
      quad_store_destroy (store);
    }
  return box_num ((boxint) loaded);
}

static caddr_t
bif_graph_load_edges (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  return bif_graph_load_edges_int (qst, err_ret, args, 0);
}

/* Same, but each row carries the weight of its edge.
 *
 * A weighted transient graph holds its own weights because there is
 * nowhere else for them to come from: a weight predicate is read from the
 * quad store, and a graph built from a query's rows has no triples
 * there. */
static caddr_t
bif_graph_load_edges_w (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  return bif_graph_load_edges_int (qst, err_ret, args, 1);
}

/* SQL: GRAPH_UNLOAD_EDGES (graph_iri) -- forget this session's transient
 * graph and drop its cached snapshot.  Returns 1 when there was one. */
static caddr_t
bif_graph_unload_edges (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t graph_arg = bif_arg (qst, args, 0, "GRAPH_UNLOAD_EDGES");
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi ? qi->qi_client : NULL;
  graph_iri_id_t graph_iri = vgraph_iri_to_id_ex (graph_arg, qst);
  (void) err_ret;
  if (!graph_iri || !cli)
    return box_num (0);
  return box_num (vgraph_edge_src_clear (graph_iri, cli) ? 1 : 0);
}

/* SQL: GRAPH_UNLOAD_TABLE (graph_iri) -- forget the table and drop the
 * cached graph.  Returns 1 when the graph was table-sourced. */
static caddr_t
bif_graph_unload_table (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t graph_arg = bif_arg (qst, args, 0, "GRAPH_UNLOAD_TABLE");
  graph_iri_id_t graph_id;
  bool had;
  (void) err_ret;
  /* Dropping a shared registration is administration, as registering it
   * is; GRAPH_LOAD_TABLE checks the same. */
  sec_check_dba ((query_instance_t *) qst, "GRAPH_UNLOAD_TABLE");
  graph_id = vgraph_iri_to_id_ex (graph_arg, qst);
  if (!graph_id)
    return box_num (0);
  had = vgraph_table_src_clear (graph_id);
  gcache_invalidate (graph_id);
  gcache_increment_generation ();
  return box_num (had ? 1 : 0);
}

/* The value of a byte-sized limit: an integer, or a string with the suffix
 * the [Graph] keys take in the INI file (K, M, G or T, each optionally
 * followed by B, or B alone), as cfg_parse_size_with_modifier() reads them.
 * That parser is in viconfig.c, which not every program linking this file
 * has.  Anything it would refuse is an error here too. */
static boxint
vgraph_size_limit_arg (caddr_t *qst, state_slot_t **args, const char *name)
{
  caddr_t arg = bif_arg (qst, args, 1, "GRAPH_SET_LIMIT");
  char *p;
  unsigned long long n, mult = 1;
  int suffix = 1;

  if (!DV_STRINGP (arg))
    return bif_long_arg (qst, args, 1, "GRAPH_SET_LIMIT");
  /* strtoull would read 'abc' as 0 and '-1' as a huge size. */
  if (!isdigit ((unsigned char) *arg))
    goto bad;
  errno = 0;
  n = strtoull (arg, &p, 10);
  if (errno == ERANGE)
    goto bad;
  switch (toupper ((unsigned char) *p))
    {
    case 'T':
      mult *= 1024;		/* FALLTHROUGH */
    case 'G':
      mult *= 1024;		/* FALLTHROUGH */
    case 'M':
      mult *= 1024;		/* FALLTHROUGH */
    case 'K':
      mult *= 1024;
      if (toupper ((unsigned char) *++p) == 'B')
	p++;
      break;
    case 'B':
      p++;
      break;
    default:
      suffix = 0;
    }
  /* A bare 0 only: '0M' is refused, as in the INI file. */
  if (*p || (n == 0 && suffix) || n > INT64_MAX / mult)
    goto bad;
  return (boxint) (n * mult);
bad:
  sqlr_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLIM02",
      "GRAPH_SET_LIMIT: %s takes a byte count with an optional K, M, G, " "T or B suffix, not '%.100s'", name, arg);
  return 0;
}

static caddr_t
bif_graph_set_limit (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "GRAPH_SET_LIMIT");
  boxint value;
  sec_check_dba ((query_instance_t *) qst, "GRAPH_SET_LIMIT");
  if (!strcmp (name, "MaxWorkspace") || !strcmp (name, "CacheMax") || !strcmp (name, "EdgeWeightMax"))
    value = vgraph_size_limit_arg (qst, args, name);
  else
    value = bif_long_arg (qst, args, 1, "GRAPH_SET_LIMIT");

  /* MaxNodes and MaxTriples are the [Graph] keys, and the names the
   * refusals give; MaxGraphNodes and MaxGraphTriples are what this
   * accepted before the INI keys lost their Graph prefix, kept so that
   * scripts written against them still work. */
  if (!strcmp (name, "MaxNodes") || !strcmp (name, "MaxGraphNodes"))
    {
      vgraph_max_graph_nodes = (int) (value < 1 ? 1 : (value > INT32_MAX ? INT32_MAX : value));
      return box_num (vgraph_max_graph_nodes);
    }
  if (!strcmp (name, "MaxTriples") || !strcmp (name, "MaxGraphTriples"))
    {
      vgraph_max_graph_triples = value < 0 ? 0 : value;
      return box_num (vgraph_max_graph_triples);
    }
  /* MaxWorkspace, CacheMax and EdgeWeightMax are in bytes, or a string
   * with a size suffix; see vgraph_size_limit_arg(). */
  if (!strcmp (name, "MaxWorkspace"))
    {
      vgraph_max_workspace = value < VGRAPH_MIN_LIMIT_BYTES ? VGRAPH_MIN_LIMIT_BYTES : (size_t) value;
      return box_num (vgraph_max_workspace);
    }
  if (!strcmp (name, "CacheMax"))
    {
      vgraph_cache_max = value < VGRAPH_MIN_LIMIT_BYTES ? VGRAPH_MIN_LIMIT_BYTES : (size_t) value;
      gcache_set_max_bytes ((uint64_t) vgraph_cache_max);
      return box_num (vgraph_cache_max);
    }
  if (!strcmp (name, "CacheTTL"))
    {
      if (value < 1)
	value = 1;
      gcache_set_ttl ((uint32_t) value);
      return box_num (value);
    }
  if (!strcmp (name, "EdgeWeightArray"))
    {
      vgraph_edge_weight_array = value ? 1 : 0;
      vgraph_edge_weights_drop ();
      /* Both of these switch which code path computes a result.  The
       * results are identical, so nothing would be wrong with serving
       * the old ones -- but then a test could not compare the two paths
       * without contriving a second graph, and an operator switching a
       * path off to diagnose a wrong answer would keep being served the
       * answer they are trying to reproduce. */
      gcache_increment_generation ();
      return box_num (vgraph_edge_weight_array);
    }
  if (!strcmp (name, "MinBatch"))
    {
      /* The row count below which a vectored BIF declines and the
       * scalar row loop runs.  Settable for the same reason IndexWalk
       * and ParallelBFS are: the two paths must return the same values,
       * and on a small fixture the vectored one is otherwise
       * unreachable -- every test would silently assert the scalar path
       * twice.  Production callers have no reason to move it. */
      vgraph_min_batch = (int) (value < 1 ? 1 : (value > INT32_MAX ? INT32_MAX : value));
      return box_num (vgraph_min_batch);
    }
  if (!strcmp (name, "IndexWalk"))
    {
      graph_algo_set_index_walk (value ? true : false);
      gcache_increment_generation ();
      return box_num (graph_algo_index_walk ()? 1 : 0);
    }
  if (!strcmp (name, "DenseNodeIndex"))
    {
      /* Read when a store is built, not per lookup, so the generation
       * bump is what makes this take effect: the next call rebuilds the
       * snapshot and the new store decides again. */
      graph_base_set_dense_index (value ? true : false);
      gcache_increment_generation ();
      return box_num (graph_base_dense_index ()? 1 : 0);
    }
  if (!strcmp (name, "NarrowEdgeIndex"))
    {
      /* Read when a store is allocated, so the generation bump is what
       * makes this take effect, exactly as for DenseNodeIndex. */
      graph_base_set_narrow_index (value ? true : false);
      gcache_increment_generation ();
      return box_num (graph_base_narrow_index ()? 1 : 0);
    }
  if (!strcmp (name, "BetweennessParallel"))
    {
      graph_algo_set_betweenness_parallel ((int) value);
      /* Invalidate, as the other execution-path switches do: without it
       * the next call is served the cached answer from the other mode,
       * which is exactly what a comparison run is trying to avoid. */
      gcache_increment_generation ();
      return box_num (graph_algo_betweenness_parallel ());
    }
  if (!strcmp (name, "PageRankGather"))
    {
      graph_algo_set_pagerank_gather ((int) value);
      gcache_increment_generation ();
      return box_num (graph_algo_pagerank_gather ());
    }
  if (!strcmp (name, "OnePredStore"))
    {
      /* Read when a store is allocated, so the generation bump is what
       * makes this take effect, as for DenseNodeIndex. */
      graph_base_set_one_pred_store (value ? true : false);
      gcache_increment_generation ();
      return box_num (graph_base_one_pred_store ()? 1 : 0);
    }
  if (!strcmp (name, "ParallelBFS"))
    {
      graph_algo_set_parallel_bfs (value ? true : false);
      gcache_increment_generation ();
      return box_num (graph_algo_parallel_bfs ()? 1 : 0);
    }
  if (!strcmp (name, "EdgeWeightMax"))
    {
      /* 0 removes the cap. */
      vgraph_edge_weight_max = value < 0 ? 0 : (size_t) value;
      return box_num (vgraph_edge_weight_max);
    }
  *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG, "VGLIM01",
      "GRAPH_SET_LIMIT: unknown limit %.100s; expected MaxNodes, "
      "MaxTriples, MaxGraphNodes, MaxGraphTriples, MaxWorkspace, "
      "CacheMax, CacheTTL, "
      "EdgeWeightArray, EdgeWeightMax, IndexWalk, DenseNodeIndex, "
      "NarrowEdgeIndex, OnePredStore, PageRankGather, BetweennessParallel, ParallelBFS or " "MinBatch", name);
  return NULL;
}

/* ============================================================================
 * THE COMMIT NOTIFIER
 *
 * Every committing transaction that changed data retires every cached
 * snapshot in the server, because the hook lock.c calls could not say what
 * had been written and the cache had nothing to go on but a global
 * counter.  A benchmark run therefore rebuilt a 12.6-second CSR after
 * every unrelated housekeeping write.
 *
 * lock.c now hands over the set of index key ids the committing
 * transaction's rollback entries name -- see graph_commit_keys_t in
 * ltrx.h -- so the question "did this write anything a cached graph
 * reads?" can be asked at table granularity, with no write path touched
 * and no row decoded.
 *
 * What is counted here is what that set actually contains in practice, so
 * that a narrowing is argued from a measurement rather than from a guess
 * about which tables a run writes.
 * ============================================================================ */

#define VGRAPH_COMMIT_KEYS_MAX 64

typedef struct vgraph_commit_key_stat
{
  int64_t key_id;
  int64_t commits;		/* commits whose written set contained this key */
} vgraph_commit_key_stat_t;

/* Written only from the notifier, which lock.c calls under the
 * transaction mutex, so the writes are serialised without a lock of their
 * own.  GRAPH_CACHE_STATUS and GRAPH_COMMIT_KEYS read them unlocked, the
 * same way every other counter in this file is read: a torn diagnostic is
 * not worth a mutex on every commit in the server. */
static vgraph_commit_key_stat_t s_commit_keys[VGRAPH_COMMIT_KEYS_MAX];
static int s_commit_keys_n = 0;
static int64_t s_commit_notifies = 0;	/* notifier calls */
static int64_t s_commit_unknown = 0;	/* ... with no trustworthy key set */
static int64_t s_commit_keys_dropped = 0;	/* distinct keys past the table */
static int64_t s_commit_skipped = 0;	/* wrote nothing a graph reads */
static int64_t s_commit_per_graph = 0;	/* retired named graphs, not all */
/* And why, by GCK_* reason.  A count per reason rather than one total,
 * because "the engine could not tell" has several causes with quite
 * different answers -- a schema change is rare and inherent, row
 * autocommit is a whole class of loader write, and no-rollback-entries at
 * all would mean the mechanism does not work here. */
static int64_t s_commit_why[GCK_N_REASONS];

static const char *const s_commit_why_name[GCK_N_REASONS] = {
  "complete", "no_rb_entries", "too_many_rb", "atomic", "log_merge",
  "schema", "row_autocommit", "2pc", "truncated"
};

static void
vgraph_commit_key_seen (int64_t key_id)
{
  int i;
  for (i = 0; i < s_commit_keys_n; i++)
    {
      if (s_commit_keys[i].key_id == key_id)
	{
	  s_commit_keys[i].commits++;
	  return;
	}
    }
  if (s_commit_keys_n >= VGRAPH_COMMIT_KEYS_MAX)
    {
      s_commit_keys_dropped++;
      return;
    }
  s_commit_keys[s_commit_keys_n].key_id = key_id;
  s_commit_keys[s_commit_keys_n].commits = 1;
  s_commit_keys_n++;
}

/* How many graphs one commit may retire individually before it is cheaper
 * and no less correct to retire everything. */
#define VGRAPH_COMMIT_GRAPHS_MAX 16

/* What a commit reaches, in the three answers that matter.
 *
 * VGRAPH_REACH_ALL is the default and the safe one: "I could not tell",
 * or a write to DB.DBA.RDF_QUAD, which every RDF-sourced graph is built
 * from and which nothing here can attribute to one graph.  VGRAPH_REACH_
 * NONE is a commit whose every written index belongs to a table no cached
 * graph reads.  VGRAPH_REACH_SOME is a commit that wrote only registered
 * source tables, and then out[] names exactly the graphs registered
 * against them. */
#define VGRAPH_REACH_NONE 0
#define VGRAPH_REACH_SOME 1
#define VGRAPH_REACH_ALL  2

static int
vgraph_commit_reach (const graph_commit_keys_t *written, graph_iri_id_t *out, int *n_out)
{
  dbe_schema_t *sc = wi_inst.wi_schema;
  int i;

  *n_out = 0;
  if (!written || !written->gck_complete || !written->gck_n_keys)
    return VGRAPH_REACH_ALL;
  if (!sc || s_table_src_unresolved)
    return VGRAPH_REACH_ALL;
  for (i = 0; i < written->gck_n_keys; i++)
    {
      dbe_key_t *key = sch_id_to_key (sc, written->gck_keys[i]);
      if (!key || !key->key_table || !key->key_table->tb_name)
	return VGRAPH_REACH_ALL;	/* cannot tell */
      if (tb_is_rdf_quad (key->key_table))
	return VGRAPH_REACH_ALL;
      if (!vgraph_table_src_graphs (key->key_table->tb_name, out, n_out, VGRAPH_COMMIT_GRAPHS_MAX))
	return VGRAPH_REACH_ALL;	/* more than fit */
    }
  return *n_out ? VGRAPH_REACH_SOME : VGRAPH_REACH_NONE;
}

/* The notifier lock.c calls after a committing transaction that changed
 * data.  Runs inside lt_commit() under the transaction mutex, so it may
 * only take mutexes that are leaves under that one, held for O(1) work, and
 * must free nothing: gcache_bump_generation() is an atomic increment,
 * gcache_invalidate_deferred() only records the graph for the next cache
 * call, a retired weight table is freed by the next weighted call, and the
 * table-source registry's mutex is taken and released without calling
 * anything.
 *
 * A commit that wrote only tables no cached graph reads retires nothing,
 * and one that wrote only registered source tables retires exactly the
 * graphs registered against them rather than every graph in the server. */
static void
vgraph_commit_notify (const graph_commit_keys_t *written)
{
  graph_iri_id_t graphs[VGRAPH_COMMIT_GRAPHS_MAX];
  int n_graphs = 0;
  int reach, i;

  s_commit_notifies++;
  if (!written || !written->gck_complete)
    {
      int why = written ? written->gck_why : GCK_NO_RB_ENTRIES;
      s_commit_unknown++;
      if (why >= 0 && why < GCK_N_REASONS)
	s_commit_why[why]++;
    }
  else
    {
      /* Count the attributable case too.  GRAPH_COMMIT_WHY reports a
       * breakdown of every commit the notifier saw, and only the failing
       * branch was counted -- so "complete", the entry that says the
       * narrowing was allowed to happen at all, was always 0 however many
       * commits had been attributed.  A reader of the breakdown would
       * have concluded the gate never narrowed anything. */
      s_commit_why[GCK_COMPLETE]++;
      for (i = 0; i < written->gck_n_keys; i++)
	vgraph_commit_key_seen ((int64_t) written->gck_keys[i]);
    }
  reach = vgraph_commit_reach (written, graphs, &n_graphs);
  if (VGRAPH_REACH_NONE == reach)
    {
      s_commit_skipped++;
      return;
    }
  if (VGRAPH_REACH_SOME == reach)
    {
      for (i = 0; i < n_graphs; i++)
	{
	  gcache_invalidate_deferred (graphs[i]);
	  vgraph_weight_cache_retire_graph (graphs[i]);
	}
      s_commit_per_graph++;
      return;
    }
  gcache_bump_generation ();
}

/* ============================================================================
 * BIF: GRAPH_COMMIT_KEYS
 *
 * SQL: GRAPH_COMMIT_KEYS()   -- read
 *      GRAPH_COMMIT_KEYS(1)  -- read and reset
 *
 * Returns: VECTOR of (key id, commits) pairs -- which indices committing
 * transactions have written since the counters were last reset, and in how
 * many commits each appeared.  Join to DB.DBA.SYS_KEYS on KEY_ID for table
 * names; key ids are per-database and mean nothing on their own.
 *
 * DBA only, for the same reason GRAPH_CACHE_STATUS is: it reports
 * server-wide write activity.
 * ============================================================================ */

static caddr_t
bif_graph_commit_keys (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t *res;
  int i, n;
  long reset = BOX_ELEMENTS (args) > 0 ? (long) bif_long_arg (qst, args, 0, "GRAPH_COMMIT_KEYS") : 0;
  (void) err_ret;
  sec_check_dba ((query_instance_t *) qst, "GRAPH_COMMIT_KEYS");
  n = s_commit_keys_n;
  if (n > VGRAPH_COMMIT_KEYS_MAX)
    n = VGRAPH_COMMIT_KEYS_MAX;
  res = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * 2 * n, DV_ARRAY_OF_POINTER);
  for (i = 0; i < n; i++)
    {
      res[2 * i] = box_num ((boxint) s_commit_keys[i].key_id);
      res[2 * i + 1] = box_num ((boxint) s_commit_keys[i].commits);
    }
  if (reset)
    {
      memset (s_commit_keys, 0, sizeof (s_commit_keys));
      memset (s_commit_why, 0, sizeof (s_commit_why));
      s_commit_keys_n = 0;
      s_commit_notifies = 0;
      s_commit_unknown = 0;
      s_commit_keys_dropped = 0;
      s_commit_skipped = 0;
      s_commit_per_graph = 0;
    }
  return (caddr_t) res;
}

/* ============================================================================
 * BIF: GRAPH_COMMIT_WHY
 *
 * SQL: GRAPH_COMMIT_WHY()
 * Returns: VECTOR of (reason, count) pairs -- why committing transactions
 * could not say which indices they wrote.  DBA only.
 * ============================================================================ */

static caddr_t
bif_graph_commit_why (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t *res;
  int i;
  (void) err_ret;
  (void) args;
  sec_check_dba ((query_instance_t *) qst, "GRAPH_COMMIT_WHY");
  res = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * 2 * GCK_N_REASONS, DV_ARRAY_OF_POINTER);
  for (i = 0; i < GCK_N_REASONS; i++)
    {
      res[2 * i] = box_dv_short_string (s_commit_why_name[i]);
      res[2 * i + 1] = box_num ((boxint) s_commit_why[i]);
    }
  return (caddr_t) res;
}

/* ============================================================================
 * BIF: GRAPH_CACHE_STATUS
 *
 * SQL: GRAPH_CACHE_STATUS()
 * Returns: VECTOR of name/value pairs describing the snapshot cache.
 *
 * Exists so that cache behaviour is observable rather than inferred from
 * wall-clock timings -- the regression tests assert on hit counts, and an
 * administrator can see whether the cache is working and how much memory
 * it holds.  DBA only: it reports server-wide activity.
 * ============================================================================ */

static caddr_t
bif_graph_cache_status (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  gcache_stats_t st;
  (void) err_ret;
  (void) args;
  sec_check_dba ((query_instance_t *) qst, "GRAPH_CACHE_STATUS");
  gcache_get_stats (&st);
  return list (70,
      box_dv_short_string ("hits"), box_num ((boxint) st.hits),
      box_dv_short_string ("misses"), box_num ((boxint) st.misses),
      box_dv_short_string ("evictions"), box_num ((boxint) st.evictions),
      box_dv_short_string ("result_evictions"), box_num ((boxint) st.result_evictions),
      /* Whole-graph results served from cache rather than recomputed.
       * The pair that makes "one HITS run answers both hub and
       * authority" an observable fact rather than a design intention. */
      box_dv_short_string ("result_hits"), box_num ((boxint) st.result_hits),
      box_dv_short_string ("result_misses"), box_num ((boxint) st.result_misses),
      box_dv_short_string ("loads"), box_num ((boxint) st.loads),
      box_dv_short_string ("entries"), box_num ((boxint) st.current_entries),
      box_dv_short_string ("memory_bytes"), box_num ((boxint) st.current_memory),
      box_dv_short_string ("peak_memory_bytes"), box_num ((boxint) st.peak_memory),
      box_dv_short_string ("generation"), box_num ((boxint) gcache_get_generation ()),
      /* What the commit notifier has been told since the counters were
       * last reset: how many committing transactions changed data, and
       * how many of those could not say which indices they wrote.  The
       * second is the number that decides whether narrowing the
       * invalidation is worth anything -- see GRAPH_COMMIT_KEYS. */
      box_dv_short_string ("commit_notifies"), box_num ((boxint) s_commit_notifies),
      box_dv_short_string ("commit_unknown"), box_num ((boxint) s_commit_unknown),
      box_dv_short_string ("commit_keys_dropped"), box_num ((boxint) s_commit_keys_dropped),
      /* Commits that retired nothing because every index they wrote
       * belongs to a table no cached graph is built from. */
      box_dv_short_string ("commit_skipped"), box_num ((boxint) s_commit_skipped),
      /* ... and commits that retired only the graphs registered against
       * the table they wrote, leaving every other cached graph alone. */
      box_dv_short_string ("commit_per_graph"), box_num ((boxint) s_commit_per_graph),
      /* Whether the commit path is collecting written keys at all.  Zero
       * on a server that has never cached a graph, which is what keeps
       * this feature off every other database's write path. */
      box_dv_short_string ("commit_gate"), box_num ((boxint) graph_commit_notify_wanted),
      box_dv_short_string ("edge_weight_builds"), box_num ((boxint) s_ew_builds),
      box_dv_short_string ("edge_weight_hits"), box_num ((boxint) s_ew_hits),
      box_dv_short_string ("edge_weight_bytes"), box_num ((boxint) s_ew_bytes),
      box_dv_short_string ("bfs_parallel_chunks"), box_num ((boxint) graph_algo_bfs_parallel_chunks ()),
      /* Workers a parallel section would get right now.  Reported
       * because a section that declines to divide its work is doing the
       * right thing on a server with one worker and the wrong thing on
       * a server with ten, and nothing in a result tells the two
       * apart. */
      box_dv_short_string ("graph_workers"), box_num ((boxint) vgraph_par_worker_count (NULL)),
      /* Whether the cached graphs' stores actually took the arithmetic
       * path.  Reported because a fast path that quietly declines looks
       * exactly like one that works: every answer is still right, and
       * only the time says otherwise. */
      box_dv_short_string ("dense_node_index"),
      box_num ((boxint) gcache_dense_stores ()),
      box_dv_short_string ("node_hash_bytes"), box_num ((boxint) gcache_node_hash_bytes ()),
      /* Whether the cached stores narrowed their endpoint index arrays
       * to 4 bytes a slot.  Reported for the same reason as
       * dense_node_index: the answers do not change with the width, so
       * only this and memory_bytes say the path ran. */
      box_dv_short_string ("narrow_edge_index"),
      box_num ((boxint) gcache_narrow_stores ()),
      box_dv_short_string ("edge_index_bytes"), box_num ((boxint) gcache_edge_index_bytes ()),
      /* Whether the cached stores dropped their per-edge records.  Same
       * reason as narrow_edge_index: no answer changes with it. */
      box_dv_short_string ("one_pred_store"),
      box_num ((boxint) gcache_one_pred_stores ()),
      box_dv_short_string ("edge_record_bytes"), box_num ((boxint) gcache_edge_record_bytes ()),
      /* Why the weight arrays were last declined, and on a miss which
       * fields of the cached pair's identity differed.  See EW_DECL_*
       * and EW_MM_* in this file. */
      box_dv_short_string ("edge_weight_decline"), box_num ((boxint) s_ew_decline),
      box_dv_short_string ("edge_weight_mismatch"), box_num ((boxint) s_ew_mismatch),
      /* The last weight-table build, split into reading the weights out
       * of RDF and sorting them. */
      box_dv_short_string ("weight_scan_ms"), box_num ((boxint) s_wl_scan_ms),
      box_dv_short_string ("weight_sort_ms"), box_num ((boxint) s_wl_sort_ms),
      box_dv_short_string ("edge_weight_resolve_ms"),
      box_num ((boxint) s_ew_resolve_ms),
      box_dv_short_string ("weight_entries"), box_num ((boxint) s_wl_entries),
      box_dv_short_string ("weight_truncated"), box_num ((boxint) s_wl_truncated));
}

/* ============================================================================
 * BIF REGISTRATION
 * ============================================================================ */

#define VGRAPH_VEC_WRAPPER(name, scalar, node_args) \
  static void name(caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret) \
  { vgraph_vec_apply(qst, err_ret, args, ret, scalar, \
      GRAPH_MIN((node_args), BOX_ELEMENTS(args))); }

VGRAPH_VEC_WRAPPER (bif_graph_degree_centrality_vec, bif_graph_degree_centrality, 1)
/* Whole-graph algorithms use true batch execution: the algorithm runs once
 * (or is served from the whole-graph result cache) and each row's value
 * comes from the O(1) snapshot node hash. */
     static void bif_graph_pagerank_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "pagerank", &vgraph_wg_pagerank);
}

/* Brandes is a whole-graph algorithm: running it once per row made a
 * vectored query over N nodes O(N*V*E). */
static void
bif_graph_betweenness_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "betweenness", &vgraph_wg_betweenness);
}

/* Closeness keeps the per-row path: graph_algo_closeness_single() runs one
 * BFS from the node being asked about, which is cheaper than the whole
 * all-sources pass when only some nodes are queried. */
VGRAPH_VEC_WRAPPER (bif_graph_closeness_vec, bif_graph_closeness, 1)
/* Harmonic is read off the same single-source BFS, through the same
 * function with the harmonic flag set, so it keeps the per-row path for
 * the same reason. */
    VGRAPH_VEC_WRAPPER (bif_graph_harmonic_vec, bif_graph_harmonic, 1)
/* HITS is a whole-graph power iteration.  The two wrappers name the same
 * compute and the same cache entry; only the half of the payload a row
 * reads differs. */
     static void bif_graph_hits_hub_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "hits_hub", &vgraph_wg_hits_hub);
}

static void
bif_graph_hits_authority_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "hits_authority", &vgraph_wg_hits_auth);
}

static void
bif_graph_eigenvector_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "eigenvector", &vgraph_wg_eigenvector);
}

/* Source-keyed traversals.  args[0] is the source and args[1] the target,
 * so the batch driver maps rows from args[1] and folds the source into the
 * cache key: one BFS answers the whole batch.  When the source varies
 * across the batch the driver declines and the row loop runs, which still
 * pays one traversal per distinct source rather than one per row.
 *
 * GRAPH_SHORTEST_PATH returns a path rather than a number, so it cannot be
 * mapped into a result data column; it keeps the scalar row loop, where it
 * reads the same cached traversal. */
VGRAPH_VEC_WRAPPER (bif_graph_shortest_path_vec, bif_graph_shortest_path, 2)
     static void bif_graph_shortest_path_length_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "shortest_path_length", &vgraph_wg_bfs_out);
}

static void
bif_graph_bfs_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  /* The no-target form (source only) returns a reachable-node count, not
   * a per-target value, so it is not a row mapping. */
  if (BOX_ELEMENTS (args) < 2)
    {
      *err_ret = BIF_NOT_VECTORED;
      return;
    }
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "bfs", &vgraph_wg_bfs);
}

static void
bif_graph_dfs_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  /* As with bfs, the no-target form returns a count rather than a
     per-row value, so it is not a row mapping. */
  if (BOX_ELEMENTS (args) < 2)
    {
      *err_ret = BIF_NOT_VECTORED;
      return;
    }
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "dfs", &vgraph_wg_dfs);
}

static void
bif_graph_label_propagation_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "label_propagation", &vgraph_wg_labelprop);
}

/* Per-node clustering coefficient (node, graph, pred) batches; the global
 * form has different argument positions and keeps the scalar row loop,
 * exactly as triangle_count does. */
static void
bif_graph_clustering_coefficient_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  if (BOX_ELEMENTS (args) >= 3)
    vgraph_vec_whole_graph (qst, err_ret, args, ret, "clustering_coefficient", &vgraph_wg_clustering);
  else
    vgraph_vec_apply (qst, err_ret, args, ret, bif_graph_clustering_coefficient, 0);
}

static void
bif_graph_wcc_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "wcc", &vgraph_wg_wcc);
}

static void
bif_graph_scc_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "scc", &vgraph_wg_scc);
}

static void
bif_graph_community_id_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  vgraph_vec_whole_graph (qst, err_ret, args, ret, "community_id", &vgraph_wg_community_id);
}

/* Per-node triangle_count (predicate-position form: node, graph, pred) uses
 * true batch execution.  The global form (graph, pred) has different
 * argument positions and keeps the scalar row loop. */
static void
bif_graph_triangle_count_vec (caddr_t *qst, caddr_t *err_ret, state_slot_t **args, state_slot_t *ret)
{
  if (BOX_ELEMENTS (args) >= 3)
    vgraph_vec_whole_graph (qst, err_ret, args, ret, "triangle_count", &vgraph_wg_triangles);
  else
    vgraph_vec_apply (qst, err_ret, args, ret, bif_graph_triangle_count, 0);
}

VGRAPH_VEC_WRAPPER (bif_graph_jaccard_similarity_vec, bif_graph_jaccard_similarity, 2)
#undef VGRAPH_VEC_WRAPPER
     void bif_graph_init (void)
{
  if (!s_edge_src_mtx)
    s_edge_src_mtx = mutex_allocate ();
  graph_snapshot_lib_init ();
  vgraph_scope_init ();
  vgraph_read_config ();
  /* Hand the async_queue executor to the graph library so algorithm
   * sections can fan out; the library runs inline until this call. */
  graph_parallel_set_ops (&vgraph_parallel_ops);
  /* Wire the RDF_QUAD commit invalidation hook so that the snapshot
   * cache is generation-stamped and stale entries are evicted after
   * every commit.  The hook is a simple global function pointer in
   * lock.c; it is NULL when the graph module is not built. */
  graph_commit_notify_set (vgraph_commit_notify);
  /* ... and the cheap test that keeps that notifier off the commit path
   * of a server which has never loaded a graph.  See ltrx.h. */
  gcache_set_host_live_fn (vgraph_gate_cache_live);
  /* ... and the teardown of anything scoped to a connection.  A
   * transient graph is owned by the session that made it and must not
   * outlive it; see the edge-source registry above. */
  graph_session_drop_set (vgraph_edge_src_drop_owner);
  /* Centrality measures — register once with bif_define_ex, using
   * BMD_ALIAS for the GRAPH_ SQL names.  This avoids the GPF
   * "bif function pointer cannot be used in two definitions" that
   * occurs when the same C function pointer is passed to both
   * bif_define_typed and bif_define_ex. */
  bif_define_ex ("degree_centrality", bif_graph_degree_centrality,
      BMD_ALIAS, "GRAPH_DEGREE_CENTRALITY",
      BMD_VECTOR_IMPL, bif_graph_degree_centrality_vec, BMD_RET_TYPE, &bt_double, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("pagerank", bif_graph_pagerank,
      BMD_ALIAS, "GRAPH_PAGERANK", BMD_VECTOR_IMPL, bif_graph_pagerank_vec, BMD_RET_TYPE, &bt_double, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("betweenness", bif_graph_betweenness,
      BMD_ALIAS, "GRAPH_BETWEENNESS",
      BMD_VECTOR_IMPL, bif_graph_betweenness_vec, BMD_RET_TYPE, &bt_double, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("closeness", bif_graph_closeness,
      BMD_ALIAS, "GRAPH_CLOSENESS", BMD_VECTOR_IMPL, bif_graph_closeness_vec, BMD_RET_TYPE, &bt_double, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("eigenvector", bif_graph_eigenvector_centrality,
      BMD_ALIAS, "GRAPH_EIGENVECTOR_CENTRALITY",
      BMD_VECTOR_IMPL, bif_graph_eigenvector_vec, BMD_RET_TYPE, &bt_double, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("shortest_path", bif_graph_shortest_path,
      BMD_ALIAS, "GRAPH_SHORTEST_PATH",
      BMD_VECTOR_IMPL, bif_graph_shortest_path_vec, BMD_RET_TYPE, &bt_any, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("shortest_path_length", bif_graph_shortest_path_length,
      BMD_ALIAS, "GRAPH_SHORTEST_PATH_LENGTH",
      BMD_VECTOR_IMPL, bif_graph_shortest_path_length_vec, BMD_RET_TYPE, &bt_integer, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("bfs", bif_graph_bfs,
      BMD_ALIAS, "GRAPH_BFS", BMD_VECTOR_IMPL, bif_graph_bfs_vec, BMD_RET_TYPE, &bt_integer, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("wcc", bif_graph_wcc,
      BMD_ALIAS, "GRAPH_WCC", BMD_VECTOR_IMPL, bif_graph_wcc_vec, BMD_RET_TYPE, &bt_integer, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("scc", bif_graph_scc,
      BMD_ALIAS, "GRAPH_SCC", BMD_VECTOR_IMPL, bif_graph_scc_vec, BMD_RET_TYPE, &bt_integer, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("community_id", bif_graph_community_id,
      BMD_ALIAS, "GRAPH_COMMUNITY_ID",
      BMD_VECTOR_IMPL, bif_graph_community_id_vec, BMD_RET_TYPE, &bt_integer, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("triangle_count", bif_graph_triangle_count,
      BMD_ALIAS, "GRAPH_TRIANGLE_COUNT",
      BMD_VECTOR_IMPL, bif_graph_triangle_count_vec, BMD_RET_TYPE, &bt_integer, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("label_propagation", bif_graph_label_propagation,
      BMD_ALIAS, "GRAPH_LABEL_PROPAGATION",
      BMD_VECTOR_IMPL, bif_graph_label_propagation_vec, BMD_RET_TYPE, &bt_integer, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("clustering_coefficient", bif_graph_clustering_coefficient,
      BMD_ALIAS, "GRAPH_CLUSTERING_COEFFICIENT",
      BMD_VECTOR_IMPL, bif_graph_clustering_coefficient_vec, BMD_RET_TYPE, &bt_double, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("jaccard_similarity", bif_graph_jaccard_similarity,
      BMD_ALIAS, "GRAPH_JACCARD_SIMILARITY",
      BMD_VECTOR_IMPL, bif_graph_jaccard_similarity_vec, BMD_RET_TYPE, &bt_double, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("harmonic", bif_graph_harmonic,
      BMD_ALIAS, "GRAPH_HARMONIC", BMD_VECTOR_IMPL, bif_graph_harmonic_vec, BMD_RET_TYPE, &bt_double, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("hits_hub", bif_graph_hits_hub,
      BMD_ALIAS, "GRAPH_HITS_HUB", BMD_VECTOR_IMPL, bif_graph_hits_hub_vec, BMD_RET_TYPE, &bt_double, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("hits_authority", bif_graph_hits_authority,
      BMD_ALIAS, "GRAPH_HITS_AUTHORITY",
      BMD_VECTOR_IMPL, bif_graph_hits_authority_vec, BMD_RET_TYPE, &bt_double, BMD_USES_INDEX, BMD_DONE);

  /* Batch Jaccard is SQL-only: it takes two vectors of nodes and
   * returns a vector of scores, which has no reading as a triple
   * pattern.  The per-pair predicate form is bif:jaccard_similarity. */
  bif_define_typed ("GRAPH_JACCARD_BATCH", bif_graph_jaccard_batch, &bt_any);

  /* Weighted centrality measures (SQL-only, no SPARQL predicate form) */
  bif_define_typed ("GRAPH_DEGREE_WEIGHTED", bif_graph_degree_weighted, &bt_double);
  bif_define_typed ("GRAPH_DEGREE_W_SPARQL", bif_graph_degree_w_sparql, &bt_double);
  bif_define_typed ("GRAPH_PAGERANK_WEIGHTED", bif_graph_pagerank_weighted, &bt_double);
  bif_define_typed ("GRAPH_BETWEENNESS_WEIGHTED", bif_graph_betweenness_weighted, &bt_double);
  bif_define_typed ("GRAPH_CLOSENESS_WEIGHTED", bif_graph_closeness_weighted, &bt_double);
  bif_define_typed ("GRAPH_EIGENVECTOR_WEIGHTED", bif_graph_eigenvector_weighted, &bt_double);

  /* Traversal — DFS is SQL-only (no bif: alias) */
  bif_define_ex ("dfs", bif_graph_dfs,
      BMD_ALIAS, "GRAPH_DFS", BMD_VECTOR_IMPL, bif_graph_dfs_vec, BMD_RET_TYPE, &bt_integer, BMD_USES_INDEX, BMD_DONE);

  /* Connected components — count variants are SQL-only */
  bif_define_typed ("GRAPH_WCC_COUNT", bif_graph_wcc_count, &bt_integer);
  bif_define_typed ("GRAPH_SCC_COUNT", bif_graph_scc_count, &bt_integer);

  /* Weighted shortest path (SQL-only) */
  bif_define_typed ("GRAPH_SHORTEST_PATH_WEIGHTED", bif_graph_shortest_path_weighted, &bt_any);
  bif_define_typed ("GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED", bif_graph_shortest_path_length_weighted, &bt_double);

  /* Cache observability and runtime limits (DBA only) */
  bif_define_typed ("GRAPH_CACHE_STATUS", bif_graph_cache_status, &bt_any);
  bif_define_typed ("GRAPH_COMMIT_KEYS", bif_graph_commit_keys, &bt_any);
  bif_define_typed ("GRAPH_COMMIT_WHY", bif_graph_commit_why, &bt_any);
  bif_define_typed ("GRAPH_SET_LIMIT", bif_graph_set_limit, &bt_integer);
  bif_define_typed ("GRAPH_LOAD_TABLE", bif_graph_load_table, &bt_integer);
  bif_define_typed ("GRAPH_LOAD_EDGES", bif_graph_load_edges, &bt_integer);
  bif_define_typed ("GRAPH_LOAD_EDGES_W", bif_graph_load_edges_w, &bt_integer);
  bif_define_typed ("GRAPH_UNLOAD_EDGES", bif_graph_unload_edges, &bt_integer);
  bif_define_typed ("GRAPH_UNLOAD_TABLE", bif_graph_unload_table, &bt_integer);

  /* Mark functions that use indexes as deadlock-unsafe */
  bif_set_uses_index (bif_graph_degree_centrality);
  bif_set_uses_index (bif_graph_degree_weighted);
  bif_set_uses_index (bif_graph_pagerank);
  bif_set_uses_index (bif_graph_betweenness);
  bif_set_uses_index (bif_graph_closeness);
  bif_set_uses_index (bif_graph_eigenvector_centrality);
  bif_set_uses_index (bif_graph_pagerank_weighted);
  bif_set_uses_index (bif_graph_betweenness_weighted);
  bif_set_uses_index (bif_graph_closeness_weighted);
  bif_set_uses_index (bif_graph_eigenvector_weighted);
  bif_set_uses_index (bif_graph_bfs);
  bif_set_uses_index (bif_graph_dfs);
  bif_set_uses_index (bif_graph_wcc);
  bif_set_uses_index (bif_graph_wcc_count);
  bif_set_uses_index (bif_graph_scc);
  bif_set_uses_index (bif_graph_scc_count);
  bif_set_uses_index (bif_graph_shortest_path_length);
  bif_set_uses_index (bif_graph_shortest_path);
  bif_set_uses_index (bif_graph_shortest_path_weighted);
  bif_set_uses_index (bif_graph_shortest_path_length_weighted);
  bif_set_uses_index (bif_graph_jaccard_similarity);
  bif_set_uses_index (bif_graph_jaccard_batch);
  bif_set_uses_index (bif_graph_harmonic);
  bif_set_uses_index (bif_graph_hits_hub);
  bif_set_uses_index (bif_graph_hits_authority);
  bif_set_uses_index (bif_graph_community_id);
  bif_set_uses_index (bif_graph_triangle_count);
  bif_set_uses_index (bif_graph_label_propagation);
  bif_set_uses_index (bif_graph_clustering_coefficient);
}
