/*
 *  graph_algo_community.c
 *
 *  Community detection and clustering algorithms
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

#include "graph_algo_advanced.h"
#include "graph_algo.h"
#include "graph_internal.h"
#include "graph_neighbor.h"
#include "graph_optim.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

#define WS_ALIGN(x) GRAPH_ALIGN_UP(x, GRAPH_CACHE_LINE_SIZE)


/* Neighbour iteration is graph_neighbor.h's, addressing rows by node index.
 * This file used to carry its own copy, comm_nb_*, which took a node id and
 * paid graph_base_find_node_index() to search a sorted table of every node
 * id for the index its caller was already holding -- once per vertex per
 * direction per iteration, and once per *edge* in the triangle and LCC
 * neighbourhood passes. */
static uint64_t
comm_cnt_nb (const graph_snapshot_t *s, uint64_t ix, graph_direction_t d, const graph_pred_filter_t *pf)
{
  neighbor_ctx_t c;
  neighbor_init_at (&c, s, ix, d, pf);
  uint64_t cnt = 0, nb;
  /* The index-only walk knows how many neighbours are left without
   * producing them: nothing is filtered out there, so what remains is
   * just what is left of the two adjacency rows.  On the general walk
   * the yielded sequence is a filtered subsequence whose length is not
   * known until it has been produced, and then counting is the only
   * option -- which is what neighbor_remaining() returning false
   * means. */
  if (neighbor_remaining (&c, &cnt))
    return cnt;
  while (neighbor_next (&c, &nb))
    cnt++;
  return cnt;
}

/* Bitmap utilities */
GRAPH_INLINE void
comm_bm_set (uint64_t *b, uint64_t i)
{
  b[i >> 6] |= (1ULL << (i & 63));
}

GRAPH_INLINE bool
comm_bm_test (const uint64_t *b, uint64_t i)
{
  return (b[i >> 6] & (1ULL << (i & 63))) != 0;
}

GRAPH_INLINE void
comm_bm_clear (uint64_t *b, uint64_t w)
{
  memset (b, 0, w * sizeof (uint64_t));
}

/* Build node map locally */
static uint64_t
comm_build_node_map (const graph_snapshot_t *s, graph_node_id_t *nm, uint64_t cap)
{
  return graph_snapshot_copy_node_map (s, nm, cap);
}

/* HITS */
size_t
graph_algo_hits_workspace_size (const graph_snapshot_t *s)
{
  if (!s)
    return 0;
  uint64_t V = s->node_count > 0 ? s->node_count : 1;
  return WS_ALIGN (sizeof (graph_workspace_header_t)) + WS_ALIGN (V * sizeof (double)) * 4 +
      WS_ALIGN (V * sizeof (graph_node_id_t));
}

graph_error_t
graph_algo_hits (const graph_snapshot_t *snap, const graph_hits_params_t *params,
    const graph_pred_filter_t *pf, void *ws, graph_hits_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  const graph_hits_params_t *p = params ? params : &GRAPH_HITS_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->node_count = 0;
      r->converged = true;
      return GRAPH_OK;
    }

  char *wp = (char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t));
  double *hub = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  double *auth = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  double *hub_new = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  double *auth_new = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  graph_node_id_t *node_map = (graph_node_id_t *) wp;

  uint64_t nc = comm_build_node_map (snap, node_map, V);
  for (uint64_t i = 0; i < nc; i++)
    {
      hub[i] = 1.0;
      auth[i] = 1.0;
    }

  int iter = 0;
  bool conv = false;
  for (; iter < p->max_iterations; iter++)
    {
      memset (auth_new, 0, nc * sizeof (double));
      for (uint64_t i = 0; i < nc; i++)
	{
	  neighbor_ctx_t ctx;
	  neighbor_init_at (&ctx, snap, i, GRAPH_DIR_OUTGOING, pf);
	  NEIGHBOR_FOREACH (ctx, j,
	      {
		auth_new[j] += hub[i];
	      }
	  );
	}
      memset (hub_new, 0, nc * sizeof (double));
      for (uint64_t i = 0; i < nc; i++)
	{
	  neighbor_ctx_t ctx;
	  neighbor_init_at (&ctx, snap, i, GRAPH_DIR_OUTGOING, pf);
	  NEIGHBOR_FOREACH (ctx, j,
	      {
		hub_new[i] += auth_new[j];
	      }
	  );
	}
      double an = 0, hn = 0;
      for (uint64_t i = 0; i < nc; i++)
	{
	  an += auth_new[i] * auth_new[i];
	  hn += hub_new[i] * hub_new[i];
	}
      an = sqrt (an);
      hn = sqrt (hn);
      double diff = 0;
      for (uint64_t i = 0; i < nc; i++)
	{
	  if (an > 0)
	    auth_new[i] /= an;
	  if (hn > 0)
	    hub_new[i] /= hn;
	  diff += fabs (auth_new[i] - auth[i]) + fabs (hub_new[i] - hub[i]);
	}
      double *t = auth;
      auth = auth_new;
      auth_new = t;
      t = hub;
      hub = hub_new;
      hub_new = t;
      if (diff < p->epsilon)
	{
	  conv = true;
	  break;
	}
    }
  r->hub_scores = hub;
  r->authority_scores = auth;
  r->node_count = nc;
  r->iterations = iter;
  r->converged = conv;
  return conv ? GRAPH_OK : GRAPH_ERR_CONVERGENCE;
}

/* Triangle counting
 *
 * The graph is treated as undirected (degree counts both directions).
 * Counting is sliced over nodes: every worker accumulates into its own
 * tri[] partials plus private bitmap and neighbor-list scratch, and
 * resolves neighbors through the snapshot hash directly, since worker
 * threads resolve neighbours through their own iterator context.  All
 * counters are uint64_t, so the per-worker partials can be summed in
 * any order and the merge stays exact - parallel and inline runs are
 * bit-identical.  Each discovered triangle contributes three increments
 * across u, v and w (two land in one slot when v == w), so the
 * discovery total is the merged sum divided by three. */
size_t
graph_algo_triangles_workspace_size (const graph_snapshot_t *s)
{
  if (!s)
    return 0;
  uint64_t V = s->node_count > 0 ? s->node_count : 1;
  uint64_t bw = (V + 63) / 64;
  size_t sz = WS_ALIGN (sizeof (graph_workspace_header_t)) + WS_ALIGN (V * sizeof (uint64_t)) * 2 +
      WS_ALIGN (bw * sizeof (uint64_t)) + WS_ALIGN (V * sizeof (graph_node_id_t)) * 2;
  /* Per-worker partial blocks: tri counts, neighbor list, bitmap. */
  sz += (size_t) graph_parallel_worker_count () *
      (WS_ALIGN (V * sizeof (uint64_t)) + WS_ALIGN (V * sizeof (graph_node_id_t)) + WS_ALIGN (bw * sizeof (uint64_t)));
  return sz;
}

typedef struct tri_deg_ctx
{
  const graph_snapshot_t *snap;
  const graph_pred_filter_t *pf;
  uint64_t *deg;
} tri_deg_ctx_t;

/* Degree pre-pass: deg[i] = outgoing + incoming neighbor count.
 * Workers write disjoint slots; comm_cnt_nb only reads the snapshot. */
static void
tri_deg_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  tri_deg_ctx_t *c = (tri_deg_ctx_t *) arg;
  (void) worker_index;
  for (uint64_t i = start; i < end; i++)
    {
      uint64_t out_deg = comm_cnt_nb (c->snap, i, GRAPH_DIR_OUTGOING, c->pf);
      uint64_t in_deg = comm_cnt_nb (c->snap, i, GRAPH_DIR_INCOMING, c->pf);
      c->deg[i] = out_deg + in_deg;
    }
}

typedef struct tri_slice_ctx
{
  const graph_snapshot_t *snap;
  const graph_pred_filter_t *pf;
  const uint64_t *deg;
  uint64_t bw;
  uint8_t *blocks;		/* base of the per-worker partial blocks */
  size_t tri_stride;		/* WS_ALIGN(V * sizeof(uint64_t)) */
  size_t list_stride;		/* WS_ALIGN(V * sizeof(graph_node_id_t)) */
} tri_slice_ctx_t;

/* One worker's pass over its u range: neighbor collection and wedge
 * checks all land in this worker's private block, keyed by
 * worker_index. */
static void
tri_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  tri_slice_ctx_t *c = (tri_slice_ctx_t *) arg;
  uint8_t *b = c->blocks + (size_t) worker_index * (c->tri_stride + c->list_stride + WS_ALIGN (c->bw * sizeof (uint64_t)));
  uint64_t *tri = (uint64_t *) b;
  uint64_t *nblist = (uint64_t *) (b + c->tri_stride);
  uint64_t *nbset = (uint64_t *) (b + c->tri_stride + c->list_stride);

  for (uint64_t u = start; u < end; u++)
    {
      comm_bm_clear (nbset, c->bw);
      uint64_t nbc = 0;
      /* Collect neighbors from both directions (undirected).
       * nblist holds the pruned neighbourhood as node *indices*.  It held
       * ids, and the wedge pass below then paid two searches of the node
       * table per entry to get back to an index and to a row -- O(E) of
       * them per run, the most expensive lookup in this file. */
      neighbor_ctx_t ctx;
      neighbor_init_at (&ctx, c->snap, u, GRAPH_DIR_OUTGOING, c->pf);
      NEIGHBOR_FOREACH (ctx, v,
	  {
	    if (v != u && (c->deg[v] > c->deg[u] || (c->deg[v] == c->deg[u] && v > u)))
	    {
	      if (!comm_bm_test (nbset, v))
	      {
	      comm_bm_set (nbset, v); nblist[nbc++] = v;}
	    }
	  }
      );
      neighbor_init_at (&ctx, c->snap, u, GRAPH_DIR_INCOMING, c->pf);
      NEIGHBOR_FOREACH (ctx, v,
	  {
	    if (v != u && (c->deg[v] > c->deg[u] || (c->deg[v] == c->deg[u] && v > u)))
	    {
	      if (!comm_bm_test (nbset, v))
	      {
	      comm_bm_set (nbset, v); nblist[nbc++] = v;}
	    }
	  }
      );
      for (uint64_t ni = 0; ni < nbc; ni++)
	{
	  uint64_t v = nblist[ni];
	  /* Check outgoing neighbors of v for triangles.
	   * Only outgoing is checked to avoid double-counting;
	   * if the edge between v and w is only w->v, the triangle
	   * will be found when processing w. */
	  neighbor_ctx_t ctx2;
	  neighbor_init_at (&ctx2, c->snap, v, GRAPH_DIR_OUTGOING, c->pf);
	  /* A triangle needs three distinct vertices; a self-loop on v
	   * would otherwise close u-v-v. */
	  NEIGHBOR_FOREACH (ctx2, w,
	      {
		if (w != v && comm_bm_test (nbset, w))
		{
		tri[u]++; tri[v]++; tri[w]++;}
	      }
	  );
	}
    }
}

/* Workspace slicing for triangle counting.
 *
 * graph_algo_clustering() runs on the same workspace and needs node_map
 * and deg[] out of it.  It used to re-derive their offsets by hand, which
 * was correct but silently coupled to the order of the wp += chain below.
 * Both functions call this instead, so a change to the layout moves both
 * at once. */
typedef struct tri_ws
{
  uint64_t *tri;
  uint64_t *deg;
  uint64_t *nbset;
  graph_node_id_t *node_map;
  uint64_t *nblist;		/* node indices, not ids */
  uint8_t *blocks;		/* per-worker partial blocks */
} tri_ws_t;

static void
tri_ws_slice (void *ws, uint64_t V, uint64_t bw, tri_ws_t *out)
{
  char *wp = (char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t));
  out->tri = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  out->deg = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  out->nbset = (uint64_t *) wp;
  wp += WS_ALIGN (bw * sizeof (uint64_t));
  out->node_map = (graph_node_id_t *) wp;
  wp += WS_ALIGN (V * sizeof (graph_node_id_t));
  out->nblist = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  out->blocks = (uint8_t *) wp;
}

graph_error_t
graph_algo_triangles (const graph_snapshot_t *snap, const graph_pred_filter_t *pf, void *ws, graph_triangles_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->node_count = 0;
      r->total_triangles = 0;
      return GRAPH_OK;
    }

  uint64_t bw = (V + 63) / 64;
  tri_ws_t w;
  tri_ws_slice (ws, V, bw, &w);
  uint64_t *tri = w.tri;
  uint64_t *deg = w.deg;
  graph_node_id_t *node_map = w.node_map;
  /* The shared nbset/nblist slots are part of the fixed layout, so that
   * the per-worker blocks start at a fixed offset; the parallel passes
   * below work in those blocks instead. */

  uint64_t nc = comm_build_node_map (snap, node_map, V);

  /* Per-worker partial blocks follow the shared arrays; the workspace
   * is sized for graph_parallel_worker_count() slots and a session can
   * only dispatch fewer, so worker_index always addresses a valid
   * block. */
  size_t tri_stride = WS_ALIGN (V * sizeof (uint64_t));
  size_t list_stride = WS_ALIGN (V * sizeof (uint64_t));
  size_t bm_stride = WS_ALIGN (bw * sizeof (uint64_t));
  size_t block_stride = tri_stride + list_stride + bm_stride;
  uint8_t *blocks = w.blocks;
  uint32_t nblocks = graph_parallel_worker_count ();

  graph_parallel_session_t *par = graph_parallel_begin (nc, GRAPH_PARALLEL_MAX_WORKERS);

  tri_deg_ctx_t dctx = { snap, pf, deg };
  graph_parallel_run (par, 0, nc, tri_deg_slice, &dctx);

  for (uint32_t k = 0; k < nblocks; k++)
    memset (blocks + (size_t) k * block_stride, 0, tri_stride);

  tri_slice_ctx_t sctx;
  sctx.snap = snap;
  sctx.pf = pf;
  sctx.deg = deg;
  sctx.bw = bw;
  sctx.blocks = blocks;
  sctx.tri_stride = tri_stride;
  sctx.list_stride = list_stride;
  graph_parallel_run (par, 0, nc, tri_slice, &sctx);
  graph_parallel_end (par);

  /* Merge the per-worker partials into the shared tri[].  Integer
   * sums are exact in any order, and every discovery contributed three
   * increments, so the merged sum divided by three is exactly the
   * sequential discovery count. */
  uint64_t total = 0;
  for (uint64_t x = 0; x < nc; x++)
    {
      uint64_t t = 0;
      for (uint32_t k = 0; k < nblocks; k++)
	t += ((const uint64_t *) (blocks + (size_t) k * block_stride))[x];
      tri[x] = t;
      total += t;
    }
  r->triangle_counts = tri;
  r->node_count = nc;
  r->total_triangles = total / 3;
  return GRAPH_OK;
}

/* LCC - local clustering coefficient.
 *
 * lcc(v) = triangles(v) / (d(v) * (d(v) - 1) / 2), and 0 when d(v) < 2.
 * The degree is the undirected one, counting a directed edge once in each
 * direction - the same convention triangle counting and
 * GRAPH_DEGREE_CENTRALITY(node, graph) use, so the three agree.
 *
 * avg_coefficient is the mean over ALL nodes, counting the d < 2 nodes as
 * the zeroes they are.  That is the mean local clustering coefficient
 * in its usual form, and it is what a caller can recompute from the
 * coefficients array alone - which matters because the BIF serves the
 * graph-wide form from a cached coefficients payload without the result
 * struct.
 *
 * The workspace is the triangle-counting one plus the coefficients array,
 * and the two arrays this needs out of it - node_map and deg[] - come
 * from tri_ws_slice() rather than from re-derived offsets.  deg[] is the
 * degree graph_algo_triangles() has just computed, so the per-node
 * comm_cnt_nb() call this used to make is gone. */
size_t
graph_algo_clustering_workspace_size (const graph_snapshot_t *s)
{
  if (!s)
    return 0;
  uint64_t V = s->node_count > 0 ? s->node_count : 1;
  return graph_algo_triangles_workspace_size (s) + WS_ALIGN (V * sizeof (double));
}

/* Directed LCC: the distinct neighbourhood over both directions, over
 * the ordered pairs of it joined by a directed edge.
 *
 * This cannot reuse the triangle pass: that one prunes the neighbourhood
 * to the higher-degree half so each triangle is discovered once, so its
 * nbset is not N(v).  Each worker rebuilds the full set in its own block
 * instead - the same blocks the triangle pass would have used, which is
 * why the workspace size does not change. */
typedef struct lccd_slice_ctx
{
  const graph_snapshot_t *snap;
  const graph_pred_filter_t *pf;
  double *coef;
  uint64_t bw;
  uint8_t *blocks;
  size_t tri_stride;
  size_t list_stride;
} lccd_slice_ctx_t;

static void
lcc_directed_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  lccd_slice_ctx_t *c = (lccd_slice_ctx_t *) arg;
  uint8_t *b = c->blocks + (size_t) worker_index * (c->tri_stride + c->list_stride + WS_ALIGN (c->bw * sizeof (uint64_t)));
  uint64_t *nblist = (uint64_t *) (b + c->tri_stride);
  uint64_t *nbset = (uint64_t *) (b + c->tri_stride + c->list_stride);

  for (uint64_t u = start; u < end; u++)
    {
      neighbor_ctx_t ctx;
      uint64_t nbc = 0, links = 0;

      comm_bm_clear (nbset, c->bw);
      neighbor_init_at (&ctx, c->snap, u, GRAPH_DIR_BOTH, c->pf);
      NEIGHBOR_FOREACH (ctx, v,
	  {
	    /* A self-loop does not make a vertex its own neighbour; were
	     * it counted, the coefficient could exceed 1. */
	    if (v == u) continue; if (!comm_bm_test (nbset, v))
	    {
	    comm_bm_set (nbset, v); nblist[nbc++] = v;}
	  }
      );
      if (nbc < 2)
	{
	  c->coef[u] = 0.0;
	  continue;
	}

      /* nblist holds indices, so the neighbourhood pass addresses each
       * neighbour's row directly instead of searching the node table
       * twice per entry -- once for the index it had a moment ago and
       * once for the row. */
      for (uint64_t ni = 0; ni < nbc; ni++)
	{
	  neighbor_ctx_t c2;
	  uint64_t x = nblist[ni];
	  neighbor_init_at (&c2, c->snap, x, GRAPH_DIR_OUTGOING, c->pf);
	  NEIGHBOR_FOREACH (c2, w,
	      {
	      if (w != x && comm_bm_test (nbset, w)) links++;}
	  );
	}
      c->coef[u] = (double) links / (double) (nbc * (nbc - 1));
    }
}

static graph_error_t
clustering_directed (const graph_snapshot_t *snap, const graph_pred_filter_t *pf,
    void *ws, double *coef, graph_clustering_result_t *r)
{
  uint64_t V = snap->node_count;
  uint64_t bw = (V + 63) / 64;
  tri_ws_t w;
  graph_workspace_header_t *header = (graph_workspace_header_t *) ws;
  uint64_t nc;
  double sum = 0;
  lccd_slice_ctx_t sctx;
  graph_parallel_session_t *par;

  tri_ws_slice (ws, V, bw, &w);
  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = GRAPH_ALGO_CLUSTERING;
  header->node_capacity = V;

  nc = comm_build_node_map (snap, w.node_map, V);
  if (nc == 0)
    {
      r->coefficients = coef;
      r->node_count = 0;
      r->avg_coefficient = 0;
      return GRAPH_OK;
    }

  par = graph_parallel_begin (nc, GRAPH_PARALLEL_MAX_WORKERS);
  sctx.snap = snap;
  sctx.pf = pf;
  sctx.coef = coef;
  sctx.bw = bw;
  sctx.blocks = w.blocks;
  sctx.tri_stride = WS_ALIGN (V * sizeof (uint64_t));
  sctx.list_stride = WS_ALIGN (V * sizeof (uint64_t));
  graph_parallel_run (par, 0, nc, lcc_directed_slice, &sctx);
  graph_parallel_end (par);

  for (uint64_t i = 0; i < nc; i++)
    sum += coef[i];
  r->coefficients = coef;
  r->node_count = nc;
  r->avg_coefficient = sum / (double) nc;
  return GRAPH_OK;
}

graph_error_t
graph_algo_clustering (const graph_snapshot_t *snap,
    const graph_clustering_params_t *params, const graph_pred_filter_t *pf, void *ws, graph_clustering_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  const graph_clustering_params_t *p = params ? params : &GRAPH_CLUSTERING_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->coefficients = NULL;
      r->node_count = 0;
      r->avg_coefficient = 0;
      return GRAPH_OK;
    }

  if (p->directed)
    return clustering_directed (snap, pf, ws, (double *) ((char *) ws + graph_algo_triangles_workspace_size (snap)), r);

  graph_triangles_result_t tr;
  graph_error_t e = graph_algo_triangles (snap, pf, ws, &tr);
  if (e != GRAPH_OK)
    return e;

  /* The coefficients array sits past the triangle workspace.  That size
   * includes per-worker blocks sized from graph_parallel_worker_count(),
   * so this call and the one the caller used to allocate must see the
   * same count: the host pins it with graph_parallel_freeze_workers()
   * for the duration of the call.  Do not compute this offset outside
   * that pinned window. */
  double *coef = (double *) ((char *) ws + graph_algo_triangles_workspace_size (snap));
  tri_ws_t w;
  tri_ws_slice (ws, V, (V + 63) / 64, &w);

  double sum = 0;
  for (uint64_t i = 0; i < tr.node_count; i++)
    {
      uint64_t d = w.deg[i];
      if (d >= 2)
	{
	  uint64_t poss = d * (d - 1) / 2;
	  coef[i] = (double) tr.triangle_counts[i] / (double) poss;
	  sum += coef[i];
	}
      else
	coef[i] = 0;
    }
  r->coefficients = coef;
  r->node_count = tr.node_count;
  r->avg_coefficient = tr.node_count > 0 ? sum / (double) tr.node_count : 0;
  return GRAPH_OK;
}

/* Louvain community detection — full two-phase implementation.
 *
 * Phase 1 (local moving): Each node joins the neighbor community that
 *   maximizes modularity gain.  Iterated until no node moves.
 * Phase 2 (aggregation): Communities are condensed into super-nodes.
 *   Edges within a community become self-loops; edges between
 *   communities become weighted inter-super-node edges.  Phase 1 runs
 *   again on the condensed graph.
 *
 * The two phases repeat until no further modularity improvement or
 * max_levels is reached.  The final community assignment is projected
 * back to the original nodes.
 */

/* Workspace layout for the condensed graph adjacency matrix.
 * The condensed graph has at most V nodes (usually much fewer after
 * each level).  We use a V×V double matrix for inter-community edge
 * weights, which is O(V^2) but simple and sufficient for moderate
 * graphs.  For very large graphs a sparse representation would be
 * better. */
/* One edge of the condensed graph.  Rows are kept sorted by dst so that
 * the double sums below run in the same order a dense row scan produced. */
typedef struct louvain_edge
{
  uint64_t dst;
  double w;
} louvain_edge_t;

static int
louvain_edge_cmp (const void *pa, const void *pb)
{
  uint64_t a = ((const louvain_edge_t *) pa)->dst;
  uint64_t b = ((const louvain_edge_t *) pb)->dst;
  return (a < b) ? -1 : (a > b) ? 1 : 0;
}

/* Edge slots the condensed graph can ever need: aggregation only merges
 * nodes, so it never has more edges than the level-0 pass emits, which is
 * one per neighbour visit, i.e. the sum of the undirected degrees. */
static uint64_t
louvain_edge_capacity (const graph_snapshot_t *s)
{
  uint64_t ee = s->triple_count * 2;
  return ee ? ee : 1;
}

size_t
graph_algo_louvain_workspace_size (const graph_snapshot_t *s)
{
  if (!s)
    return 0;
  uint64_t V = s->node_count > 0 ? s->node_count : 1;
  uint64_t EE = louvain_edge_capacity (s);
  /* The condensed graph used to be a dense V x V double matrix, which
   * against a 64 MB workspace capped GRAPH_COMMUNITY_ID at about 2,896
   * nodes regardless of how sparse the graph was.  It is a CSR now, so
   * the cost is proportional to edges rather than to nodes squared. */
  return WS_ALIGN (sizeof (graph_workspace_header_t)) + WS_ALIGN (V * sizeof (uint64_t))	/* comm */
      + WS_ALIGN (V * sizeof (uint64_t))	/* cw (community weights) */
      + WS_ALIGN (V * sizeof (uint64_t))	/* nc_tmp */
      + WS_ALIGN (V * sizeof (double))	/* ki (node degrees) */
      + WS_ALIGN (V * sizeof (graph_node_id_t))	/* node_map */
      + WS_ALIGN (V * sizeof (uint64_t))	/* orig_comm (level 0 assignment) */
      + WS_ALIGN ((V + 1) * sizeof (uint64_t)) * 4	/* off_a, off_b, cursor, touched */
      + WS_ALIGN (EE * sizeof (louvain_edge_t)) * 2;	/* edges_a, edges_b */
}

/* Compact raw (row, dst, w) entries already placed by a counting pass into
 * a merged CSR: sort each row by dst, add duplicate targets together, and
 * close the gaps.  off[] is a prefix-sum array, so off[i+1] is both the end
 * of row i and the start of row i+1; it is only rewritten after it has been
 * read, which is why this can run in place. */
static void
louvain_csr_compact (uint64_t n, uint64_t *off, louvain_edge_t *edges)
{
  uint64_t write = 0, i;
  for (i = 0; i < n; i++)
    {
      uint64_t start = off[i], end = off[i + 1], r;
      uint64_t row_start = write;
      if (end > start + 1)
	qsort (&edges[start], (size_t) (end - start), sizeof (louvain_edge_t), louvain_edge_cmp);
      for (r = start; r < end; r++)
	{
	  if (write > row_start && edges[write - 1].dst == edges[r].dst)
	    edges[write - 1].w += edges[r].w;
	  else
	    edges[write++] = edges[r];
	}
      off[i] = row_start;
    }
  off[n] = write;
}

static int
louvain_u64_cmp (const void *pa, const void *pb)
{
  uint64_t a = *(const uint64_t *) pa, b = *(const uint64_t *) pb;
  return (a < b) ? -1 : (a > b) ? 1 : 0;
}

/* One local-moving step for node i.
 *
 * The dense form memset the whole community-count array and then scanned
 * every community, which made each pass O(V^2) however sparse the graph
 * was.  Only the communities the node actually touches can win, so they
 * are collected in `touched`, sorted ascending, and scanned in that order
 * -- the same order, over the same candidates, the full scan produced, so
 * the choice (including tie-breaking) is unchanged.  The current community
 * is always a candidate even when nothing points at it; a community with a
 * zero count can never win, since its delta is <= 0 and best_d starts at 0.
 *
 * Returns true when the node moved. */
static bool
louvain_pick_community (uint64_t i, uint64_t *comm, double *ki,
    uint64_t *cw, uint64_t *nc_tmp, uint64_t *touched, uint64_t n_touched, double m, double resolution)
{
  uint64_t cc = comm[i];
  uint64_t t;
  double best_d = 0;
  uint64_t best_c = cc;
  bool moved = false;

  if (nc_tmp[cc] == 0)
    {
      /* not touched by any neighbour, but still a candidate */
      touched[n_touched++] = cc;
    }
  if (n_touched > 1)
    qsort (touched, (size_t) n_touched, sizeof (uint64_t), louvain_u64_cmp);

  cw[cc] -= (uint64_t) ki[i];
  for (t = 0; t < n_touched; t++)
    {
      uint64_t c = touched[t];
      double d;
      if (t && touched[t - 1] == c)
	continue;		/* cc may repeat */
      d = (double) nc_tmp[c] - resolution * ki[i] * (double) cw[c] / (2.0 * m);
      if (d > best_d)
	{
	  best_d = d;
	  best_c = c;
	}
    }
  if (best_c != cc)
    {
      comm[i] = best_c;
      cw[best_c] += (uint64_t) ki[i];
      moved = true;
    }
  else
    {
      cw[cc] += (uint64_t) ki[i];
    }
  for (t = 0; t < n_touched; t++)
    nc_tmp[touched[t]] = 0;
  return moved;
}

/* Phase 1: local moving on the original graph (first level only).
 * Uses the snapshot's neighbor iteration.  nc_tmp is all zeroes on entry
 * and is left that way by louvain_pick_community(). */
static bool
louvain_phase1_original (const graph_snapshot_t *snap, const graph_pred_filter_t *pf,
    uint64_t nc,
    uint64_t *comm, double *ki, uint64_t *cw, uint64_t *nc_tmp, uint64_t *touched, double m, double resolution, int max_iterations)
{
  bool improved = false;
  memset (nc_tmp, 0, nc * sizeof (uint64_t));
  for (int it = 0; it < max_iterations; it++)
    {
      bool moved = false;
      for (uint64_t i = 0; i < nc; i++)
	{
	  uint64_t n_touched = 0;
	  neighbor_ctx_t ctx;
	  neighbor_init_at (&ctx, snap, i, GRAPH_DIR_BOTH, pf);
	  NEIGHBOR_FOREACH (ctx, j,
	      {
	      if (nc_tmp[comm[j]] == 0) touched[n_touched++] = comm[j]; nc_tmp[comm[j]]++;}
	  );
	  if (louvain_pick_community (i, comm, ki, cw, nc_tmp, touched, n_touched, m, resolution))
	    moved = improved = true;
	}
      if (!moved)
	break;
    }
  return improved;
}

/* Phase 1: local moving on the condensed graph (levels > 0).
 * Walks the condensed CSR; a dense row scan differed only by visiting the
 * zero cells, which contribute nothing. */
static bool
louvain_phase1_condensed (uint64_t nc_cond, const uint64_t *off, const louvain_edge_t *edges,
    uint64_t *comm, double *ki, uint64_t *cw, uint64_t *nc_tmp, uint64_t *touched, double m, double resolution, int max_iterations)
{
  bool improved = false;
  memset (nc_tmp, 0, nc_cond * sizeof (uint64_t));
  for (int it = 0; it < max_iterations; it++)
    {
      bool moved = false;
      for (uint64_t i = 0; i < nc_cond; i++)
	{
	  uint64_t n_touched = 0;
	  /* Count edges from i to each community */
	  for (uint64_t e = off[i]; e < off[i + 1]; e++)
	    {
	      double w = edges[e].w;
	      uint64_t c;
	      if (!(w > 0))
		continue;
	      c = comm[edges[e].dst];
	      if (nc_tmp[c] == 0)
		touched[n_touched++] = c;
	      nc_tmp[c] += (uint64_t) w;
	    }
	  if (louvain_pick_community (i, comm, ki, cw, nc_tmp, touched, n_touched, m, resolution))
	    moved = improved = true;
	}
      if (!moved)
	break;
    }
  return improved;
}

graph_error_t
graph_algo_louvain (const graph_snapshot_t *snap, const graph_louvain_params_t *params,
    const graph_pred_filter_t *pf, void *ws, graph_louvain_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  const graph_louvain_params_t *p = params ? params : &GRAPH_LOUVAIN_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->node_count = 0;
      r->community_count = 0;
      return GRAPH_OK;
    }

  char *wp = (char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t));
  uint64_t *comm = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  uint64_t *cw = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  uint64_t *nc_tmp = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  double *ki = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  graph_node_id_t *node_map = (graph_node_id_t *) wp;
  wp += WS_ALIGN (V * sizeof (graph_node_id_t));
  uint64_t *orig_comm = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  /* Condensed graph as a CSR, double-buffered so a level can be built
   * from the previous one without a dense temporary. */
  uint64_t EE = louvain_edge_capacity (snap);
  uint64_t *off_a = (uint64_t *) wp;
  wp += WS_ALIGN ((V + 1) * sizeof (uint64_t));
  uint64_t *off_b = (uint64_t *) wp;
  wp += WS_ALIGN ((V + 1) * sizeof (uint64_t));
  uint64_t *cur = (uint64_t *) wp;
  wp += WS_ALIGN ((V + 1) * sizeof (uint64_t));
  uint64_t *touched = (uint64_t *) wp;
  wp += WS_ALIGN ((V + 1) * sizeof (uint64_t));
  louvain_edge_t *edges_a = (louvain_edge_t *) wp;
  wp += WS_ALIGN (EE * sizeof (louvain_edge_t));
  louvain_edge_t *edges_b = (louvain_edge_t *) wp;
  uint64_t *off = off_a;
  louvain_edge_t *edges = edges_a;

  uint64_t nc = comm_build_node_map (snap, node_map, V);

  /* Compute degrees and total edge weight.
   * ki[i] = degree of node i (both directions, so each undirected
   * edge contributes 1 to each endpoint's ki).  m = sum(ki)/2. */
  double m = 0;
  for (uint64_t i = 0; i < nc; i++)
    {
      comm[i] = i;
      ki[i] = (double) comm_cnt_nb (snap, i, GRAPH_DIR_BOTH, pf);
      m += ki[i];
      cw[i] = (uint64_t) ki[i];
    }
  m /= 2.0;
  if (m == 0)
    {
      r->community_ids = comm;
      r->node_count = nc;
      r->community_count = nc;
      r->modularity = 0;
      r->levels = 0;
      return GRAPH_OK;
    }

  /* Save original node-to-community mapping for back-projection.
   * orig_comm[i] holds the community of original node i, updated
   * through each aggregation level. */
  for (uint64_t i = 0; i < nc; i++)
    orig_comm[i] = i;

  int levels = 0;
  bool global_improved = true;

  while (global_improved && levels < p->max_levels)
    {
      /* Phase 1: local moving on the current graph representation */
      if (levels == 0)
	{
	  louvain_phase1_original (snap, pf, nc, comm, ki, cw, nc_tmp, touched, m, p->resolution, p->max_iterations);
	}
      else
	{
	  louvain_phase1_condensed (nc, off, edges, comm, ki, cw, nc_tmp, touched, m, p->resolution, p->max_iterations);
	}

      /* Remap community IDs to consecutive range [0, n_communities) */
      memset (nc_tmp, 0xFF, nc * sizeof (uint64_t));
      uint64_t n_communities = 0;
      for (uint64_t i = 0; i < nc; i++)
	{
	  if (nc_tmp[comm[i]] == UINT64_MAX)
	    nc_tmp[comm[i]] = n_communities++;
	  comm[i] = nc_tmp[comm[i]];
	}

      /* Project community assignments back to original nodes.
       * orig_comm[i] = comm[orig_comm[i]] composes the current
       * level's mapping with all previous levels. */
      for (uint64_t i = 0; i < V; i++)
	{
	  if (orig_comm[i] < nc)
	    orig_comm[i] = comm[orig_comm[i]];
	}

      if (n_communities == nc)
	{
	  /* No communities merged — convergence */
	  global_improved = false;
	  break;
	}

      /* Phase 2: aggregation — build condensed graph.
       * The condensed graph has n_communities super-nodes.
       * Edge weights between super-nodes are the sum of edges
       * between their member nodes.  Self-loops represent
       * intra-community edges. */

      /* Build the next level's CSR into the spare buffer.  Rows are
       * counted, filled, then sorted and merged, so a row ends up in
       * ascending dst order with duplicate targets summed - the same
       * values, in the same order, a dense row scan produced. */
      {
	uint64_t *new_off = (off == off_a) ? off_b : off_a;
	louvain_edge_t *new_edges = (edges == edges_a) ? edges_b : edges_a;
	uint64_t i, e, total;

	memset (new_off, 0, (n_communities + 1) * sizeof (uint64_t));
	if (levels == 0)
	  {
	    for (i = 0; i < nc; i++)
	      {
		neighbor_ctx_t ctx;
		neighbor_init_at (&ctx, snap, i, GRAPH_DIR_BOTH, pf);
		NEIGHBOR_FOREACH (ctx, nb,
		    {
		      (void) nb;
		      new_off[comm[i] + 1]++;
		    });
	      }
	  }
	else
	  {
	    for (i = 0; i < nc; i++)
	      for (e = off[i]; e < off[i + 1]; e++)
		if (edges[e].w != 0.0)
		  new_off[comm[i] + 1]++;
	  }
	for (i = 0; i < n_communities; i++)
	  new_off[i + 1] += new_off[i];
	total = new_off[n_communities];
	if (total > EE)
	  {
	    /* Cannot happen -- aggregation only merges -- but never
	     * write past the workspace if it ever did. */
	    global_improved = false;
	    break;
	  }
	memcpy (cur, new_off, n_communities * sizeof (uint64_t));
	if (levels == 0)
	  {
	    for (i = 0; i < nc; i++)
	      {
		neighbor_ctx_t ctx;
		neighbor_init_at (&ctx, snap, i, GRAPH_DIR_BOTH, pf);
		NEIGHBOR_FOREACH (ctx, j,
		    {
		    new_edges[cur[comm[i]]].dst = comm[j]; new_edges[cur[comm[i]]].w = 1.0; cur[comm[i]]++;}
		);
	      }
	  }
	else
	  {
	    for (i = 0; i < nc; i++)
	      {
		uint64_t ci = comm[i];
		for (e = off[i]; e < off[i + 1]; e++)
		  {
		    if (edges[e].w == 0.0)
		      continue;
		    new_edges[cur[ci]].dst = comm[edges[e].dst];
		    new_edges[cur[ci]].w = edges[e].w;
		    cur[ci]++;
		  }
	      }
	  }
	louvain_csr_compact (n_communities, new_off, new_edges);
	off = new_off;
	edges = new_edges;
      }

      /* Recompute degrees for condensed graph */
      nc = n_communities;
      for (uint64_t i = 0; i < nc; i++)
	{
	  comm[i] = i;
	  ki[i] = 0;
	  for (uint64_t e = off[i]; e < off[i + 1]; e++)
	    ki[i] += edges[e].w;
	  cw[i] = (uint64_t) ki[i];
	}
      /* Recompute m for condensed graph */
      m = 0;
      for (uint64_t i = 0; i < nc; i++)
	m += ki[i];
      m /= 2.0;

      levels++;
      global_improved = true;	/* try another level */
    }

  /* Back-project: orig_comm[i] now holds the final community for
   * original node i, composed through all aggregation levels. */
  /* Remap to consecutive IDs */
  memset (nc_tmp, 0xFF, V * sizeof (uint64_t));
  uint64_t final_cc = 0;
  for (uint64_t i = 0; i < V; i++)
    {
      if (nc_tmp[orig_comm[i]] == UINT64_MAX)
	nc_tmp[orig_comm[i]] = final_cc++;
    }
  for (uint64_t i = 0; i < V; i++)
    comm[i] = nc_tmp[orig_comm[i]];

  /* Compute modularity on the original graph */
  double mod = 0;
  double orig_m = 0;
  for (uint64_t i = 0; i < V; i++)
    {
      /* Recompute original ki for modularity */
      /* Actually, ki was overwritten for condensed graph.
       * Recompute from snapshot. */
    }
  /* Recompute original degrees for modularity */
  {
    double orig_ki;
    for (uint64_t i = 0; i < nc; i++)
      {
	orig_ki = (double) comm_cnt_nb (snap, i, GRAPH_DIR_BOTH, pf);
	orig_m += orig_ki;
      }
    orig_m /= 2.0;
    if (orig_m > 0)
      {
	for (uint64_t i = 0; i < nc; i++)
	  {
	    double ki_i = (double) comm_cnt_nb (snap, i, GRAPH_DIR_BOTH, pf);
	    neighbor_ctx_t ctx;
	    neighbor_init_at (&ctx, snap, i, GRAPH_DIR_BOTH, pf);
	    NEIGHBOR_FOREACH (ctx, j,
		{
		  if (comm[i] == comm[j])
		  {
		  double ki_j = (double) comm_cnt_nb (snap, j, GRAPH_DIR_BOTH, pf); mod += 1.0 - ki_i * ki_j / (2.0 * orig_m);}
		});
	  }
	mod /= (2.0 * orig_m);
      }
  }

  /* Recompute original nc for the result */
  uint64_t orig_nc = comm_build_node_map (snap, node_map, V);

  r->community_ids = comm;
  r->node_count = orig_nc;
  r->community_count = final_cc;
  r->modularity = mod;
  r->levels = levels;
  return GRAPH_OK;
}


/* CDLP - community detection by label propagation.
 *
 * Synchronous: every node reads the previous iteration's labels, so the
 * result does not depend on the order nodes are visited in, which is what
 * makes the per-node pass safe to slice across workers.  Ties go to the
 * smallest label among those with the highest frequency.  Neighbours are
 * GRAPH_DIR_BOTH, and an edge present in both directions is counted
 * twice - the usual rule that a directed edge counts once in each
 * direction.
 *
 * The per-node tally reuses Louvain's trick (louvain_pick_community):
 * count into nc_tmp indexed by label, remember each first-touched label in
 * touched, sort touched ascending, scan, then clear only what was touched.
 * That is O(degree) per node rather than O(V) - and the ascending scan
 * with a strict > comparison is exactly CDLP's smallest-label tie-break,
 * with no extra comparison.
 *
 * nc_tmp and touched are per-worker blocks sized from
 * graph_parallel_worker_count(), the way triangle counting and closeness
 * size theirs; the count is pinned by the caller for the duration of the
 * call, so the sizing pass and the slicing pass agree. */
size_t
graph_algo_labelprop_workspace_size (const graph_snapshot_t *s)
{
  if (!s)
    return 0;
  uint64_t V = s->node_count > 0 ? s->node_count : 1;
  size_t sz = WS_ALIGN (sizeof (graph_workspace_header_t)) + WS_ALIGN (V * sizeof (uint64_t)) * 2	/* labels, new_labels */
      + WS_ALIGN (V * sizeof (graph_node_id_t));	/* node_map */
  /* Per-worker tally scratch: nc_tmp indexed by label, touched holding
   * the distinct labels this node's neighbours carry. */
  sz += (size_t) graph_parallel_worker_count () * WS_ALIGN (V * sizeof (uint64_t)) * 2;
  return sz;
}

typedef struct lp_slice_ctx
{
  const graph_snapshot_t *snap;
  const graph_pred_filter_t *pf;
  const uint64_t *labels;	/* previous iteration, read-only */
  uint64_t *new_labels;		/* this iteration, one slot per node */
  uint8_t *blocks;		/* base of the per-worker scratch blocks */
  size_t tmp_stride;		/* WS_ALIGN(V * sizeof(uint64_t)) */
} lp_slice_ctx_t;

/* One worker's pass over its node range.  Pure gather: it writes only
 * new_labels[i] for i in its own slice and reads only labels[], which no
 * worker writes this iteration, so the result is identical inline and
 * under any partition. */
static void
lp_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  lp_slice_ctx_t *c = (lp_slice_ctx_t *) arg;
  uint8_t *b = c->blocks + (size_t) worker_index * c->tmp_stride * 2;
  uint64_t *nc_tmp = (uint64_t *) b;
  uint64_t *touched = (uint64_t *) (b + c->tmp_stride);

  for (uint64_t i = start; i < end; i++)
    {
      uint64_t n_touched = 0, t;
      uint64_t best = c->labels[i], best_cnt = 0;
      neighbor_ctx_t ctx;

      neighbor_init_at (&ctx, c->snap, i, GRAPH_DIR_BOTH, c->pf);
      NEIGHBOR_FOREACH (ctx, j,
	  {
	  uint64_t l = c->labels[j]; if (nc_tmp[l] == 0) touched[n_touched++] = l; nc_tmp[l]++;}
      );
      /* Ties go to the smallest label.  This used to sort `touched`
       * ascending and take the first label to reach the maximum count,
       * which is the same answer and a qsort per node per iteration to
       * get it -- 6.3 million calls through a function pointer on a
       * graph of 633,432 vertices at ten iterations, over an average of
       * 108 neighbours each.  Comparing the label as well as the count
       * needs no order at all.
       *
       * The two are the same choice, not merely similar.  Every touched
       * label has a count of at least one and best_cnt starts at zero,
       * so the first candidate always wins on count and the tie-break
       * is never applied against the initial state; after that the
       * smallest label among those with the highest count wins, which
       * is exactly what the first label to reach the maximum was in
       * ascending order.  A node with no neighbours keeps its own
       * label under both. */
      for (t = 0; t < n_touched; t++)
	{
	  uint64_t l = touched[t];
	  uint64_t cnt = nc_tmp[l];
	  if (cnt > best_cnt || (cnt == best_cnt && l < best))
	    {
	      best_cnt = cnt;
	      best = l;
	    }
	  nc_tmp[l] = 0;	/* leave the block zeroed for the next node */
	}
      c->new_labels[i] = best;
    }
}

graph_error_t
graph_algo_labelprop (const graph_snapshot_t *snap,
    const graph_labelprop_params_t *params, const graph_pred_filter_t *pf, void *ws, graph_labelprop_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  const graph_labelprop_params_t *p = params ? params : &GRAPH_LABELPROP_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->labels = NULL;
      r->node_count = 0;
      r->community_count = 0;
      r->iterations = 0;
      return GRAPH_OK;
    }

  char *wp = (char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t));
  uint64_t *labels = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  uint64_t *new_labels = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  graph_node_id_t *node_map = (graph_node_id_t *) wp;
  wp += WS_ALIGN (V * sizeof (graph_node_id_t));
  uint8_t *blocks = (uint8_t *) wp;
  size_t tmp_stride = WS_ALIGN (V * sizeof (uint64_t));
  uint32_t nblocks = graph_parallel_worker_count ();
  uint32_t k;
  int iter = 0;

  graph_workspace_header_t *header = (graph_workspace_header_t *) ws;
  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = GRAPH_ALGO_LABEL_PROP;
  header->node_capacity = V;

  uint64_t nc = comm_build_node_map (snap, node_map, V);
  if (nc == 0)
    {
      r->labels = labels;
      r->node_count = 0;
      r->community_count = 0;
      r->iterations = 0;
      return GRAPH_OK;
    }

  for (uint64_t i = 0; i < nc; i++)
    labels[i] = i;
  /* lp_slice leaves nc_tmp zeroed, so one clear up front is enough. */
  for (k = 0; k < nblocks; k++)
    memset (blocks + (size_t) k * tmp_stride * 2, 0, (size_t) nc * sizeof (uint64_t));

  graph_parallel_session_t *par = graph_parallel_begin (nc, GRAPH_PARALLEL_MAX_WORKERS);

  for (iter = 0; iter < p->max_iterations; iter++)
    {
      lp_slice_ctx_t sctx;
      bool changed = false;
      sctx.snap = snap;
      sctx.pf = pf;
      sctx.labels = labels;
      sctx.new_labels = new_labels;
      sctx.blocks = blocks;
      sctx.tmp_stride = tmp_stride;
      graph_parallel_run (par, 0, nc, lp_slice, &sctx);
      for (uint64_t i = 0; i < nc; i++)
	{
	  if (new_labels[i] != labels[i])
	    {
	      changed = true;
	      break;
	    }
	}
      {				/* swap: this iteration's output becomes the next one's input */
	uint64_t *t = labels;
	labels = new_labels;
	new_labels = t;
      }
      /* A fixed point repeats forever, so stopping there is the same
       * answer max_iterations would have given, only sooner. */
      if (!changed)
	{
	  iter++;
	  break;
	}
    }
  graph_parallel_end (par);

  /* Renumber to a dense [0, community_count) range, ascending by first
   * appearance in node-map order, so the ids are stable across runs and
   * comparable with the other community algorithms.  new_labels is free
   * scratch at this point; it holds "old label -> dense id" and is
   * indexed by label, which is always a node index in [0, nc). */
  if (GRAPH_LABELPROP_LABELS_NODE_ID == p->label_form)
    {
      /* The label a node settled on is the index of the node the
       * community is named after, so node_map turns it into that
       * vertex's own id.  Counting the distinct labels still needs the
       * same scratch pass; only the value written back differs. */
      uint64_t cc = 0;
      memset (new_labels, 0xFF, (size_t) nc * sizeof (uint64_t));
      for (uint64_t i = 0; i < nc; i++)
	{
	  uint64_t l = labels[i];
	  if (new_labels[l] == UINT64_MAX)
	    new_labels[l] = cc++;
	}
      for (uint64_t i = 0; i < nc; i++)
	labels[i] = (uint64_t) node_map[labels[i]];
      r->community_count = cc;
    }
  else
    {
      uint64_t cc = 0;
      memset (new_labels, 0xFF, (size_t) nc * sizeof (uint64_t));
      for (uint64_t i = 0; i < nc; i++)
	{
	  uint64_t l = labels[i];
	  if (new_labels[l] == UINT64_MAX)
	    new_labels[l] = cc++;
	  labels[i] = new_labels[l];
	}
      r->community_count = cc;
    }
  r->labels = labels;
  r->node_count = nc;
  r->iterations = iter;
  return GRAPH_OK;
}

/* K-means clustering */
size_t
graph_algo_kmeans_workspace_size (uint64_t n, uint32_t k, uint32_t d)
{
  return WS_ALIGN (sizeof (graph_workspace_header_t)) + WS_ALIGN (n * sizeof (uint32_t)) +
      WS_ALIGN (k * d * sizeof (double)) * 2 + WS_ALIGN (k * sizeof (uint64_t));
}

static double
km_dist (const double *a, const double *b, uint32_t d)
{
  double s = 0;
  for (uint32_t i = 0; i < d; i++)
    {
      double df = a[i] - b[i];
      s += df * df;
    }
  return sqrt (s);
}

graph_error_t
graph_algo_kmeans (const double *feat, uint64_t n, uint32_t dim,
    const graph_kmeans_params_t *params, void *ws, graph_kmeans_result_t *r)
{
  if (!feat || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  const graph_kmeans_params_t *p = params ? params : &GRAPH_KMEANS_DEFAULT;
  uint32_t k = p->k;
  if (k == 0 || k > n)
    return GRAPH_ERR_INVALID_PARAM;

  char *wp = (char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t));
  uint32_t *cid = (uint32_t *) wp;
  wp += WS_ALIGN (n * sizeof (uint32_t));
  double *cent = (double *) wp;
  wp += WS_ALIGN (k * dim * sizeof (double));
  double *cent_new = (double *) wp;
  wp += WS_ALIGN (k * dim * sizeof (double));
  uint64_t *csz = (uint64_t *) wp;

  uint64_t step = n / k;
  for (uint32_t c = 0; c < k; c++)
    memcpy (&cent[c * dim], &feat[c * step * dim], dim * sizeof (double));

  int iter = 0;
  bool conv = false;
  double inertia = 0;
  for (; iter < p->max_iterations; iter++)
    {
      inertia = 0;
      for (uint64_t i = 0; i < n; i++)
	{
	  double mind = DBL_MAX;
	  uint32_t bc = 0;
	  for (uint32_t c = 0; c < k; c++)
	    {
	      double d = km_dist (&feat[i * dim], &cent[c * dim], dim);
	      if (d < mind)
		{
		  mind = d;
		  bc = c;
		}
	    }
	  cid[i] = bc;
	  inertia += mind * mind;
	}
      memset (cent_new, 0, k * dim * sizeof (double));
      memset (csz, 0, k * sizeof (uint64_t));
      for (uint64_t i = 0; i < n; i++)
	{
	  uint32_t c = cid[i];
	  csz[c]++;
	  for (uint32_t d = 0; d < dim; d++)
	    cent_new[c * dim + d] += feat[i * dim + d];
	}
      double maxs = 0;
      for (uint32_t c = 0; c < k; c++)
	{
	  if (csz[c] > 0)
	    for (uint32_t d = 0; d < dim; d++)
	      cent_new[c * dim + d] /= csz[c];
	  double s = km_dist (&cent[c * dim], &cent_new[c * dim], dim);
	  if (s > maxs)
	    maxs = s;
	}
      memcpy (cent, cent_new, k * dim * sizeof (double));
      if (maxs < p->epsilon)
	{
	  conv = true;
	  break;
	}
    }
  r->cluster_ids = cid;
  r->centroids = cent;
  r->node_count = n;
  r->k = k;
  r->dimension = dim;
  r->iterations = iter;
  r->inertia = inertia;
  r->converged = conv;
  return GRAPH_OK;
}

/* KNN */
size_t
graph_algo_knn_workspace_size (const graph_snapshot_t *s, uint32_t k)
{
  return graph_algo_dijkstra_workspace_size (s) + WS_ALIGN (k * sizeof (graph_node_id_t)) + WS_ALIGN (k * sizeof (double));
}

graph_error_t
graph_algo_knn (const graph_snapshot_t *snap, graph_node_id_t src, uint32_t k,
    graph_direction_t dir, const graph_pred_filter_t *pf, graph_weight_func_t wf, void *wud, void *ws, graph_knn_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;

  graph_dijkstra_result_t dj;
  graph_error_t e = graph_algo_dijkstra (snap, src, dir, pf, wf, wud, NULL, ws, &dj);
  if (e != GRAPH_OK)
    return e;

  char *wp = (char *) ws + graph_algo_dijkstra_workspace_size (snap);
  graph_node_id_t *nb = (graph_node_id_t *) wp;
  wp += WS_ALIGN (k * sizeof (graph_node_id_t));
  double *dist = (double *) wp;

  for (uint32_t i = 0; i < k; i++)
    {
      nb[i] = GRAPH_NODE_ID_INVALID;
      dist[i] = INFINITY;
    }

  uint64_t V = snap->node_count;
  graph_node_id_t *nm = (graph_node_id_t *) ((char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t)) +
      WS_ALIGN (((V + 63) / 64) * sizeof (uint64_t)) + WS_ALIGN (V * sizeof (double)) +
      WS_ALIGN (V * sizeof (graph_node_id_t)) * 3 + WS_ALIGN (V * sizeof (uint64_t)));

  uint32_t found = 0;
  for (uint64_t i = 0; i < dj.node_count; i++)
    {
      if (nm[i] == src || dj.distances[i] == INFINITY)
	continue;
      if (found < k || dj.distances[i] < dist[k - 1])
	{
	  uint32_t pos = found < k ? found : k - 1;
	  while (pos > 0 && dj.distances[i] < dist[pos - 1])
	    {
	      dist[pos] = dist[pos - 1];
	      nb[pos] = nb[pos - 1];
	      pos--;
	    }
	  dist[pos] = dj.distances[i];
	  nb[pos] = nm[i];
	  if (found < k)
	    found++;
	}
    }
  r->neighbors = nb;
  r->distances = dist;
  r->k = k;
  r->found = found;
  return GRAPH_OK;
}
