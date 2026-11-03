/*
 *  graph_algo_advanced.c
 *
 *  Advanced graph algorithm implementations
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
#include "graph_reduce.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

/* Default parameters */
const graph_betweenness_params_t GRAPH_BETWEENNESS_DEFAULT = {
  .normalized = true,.endpoints = false,.directed = true,.sample_size = 0,.seed = 0
};

const graph_closeness_params_t GRAPH_CLOSENESS_DEFAULT = {
  .normalized = true,.harmonic = false,.direction = GRAPH_DIR_OUTGOING
};

const graph_eigenvector_params_t GRAPH_EIGENVECTOR_DEFAULT = {
  .epsilon = 1e-6,.max_iterations = 100
};

const graph_hits_params_t GRAPH_HITS_DEFAULT = {
  .epsilon = 1e-6,.max_iterations = 100
};

const graph_louvain_params_t GRAPH_LOUVAIN_DEFAULT = {
  .resolution = 1.0,.epsilon = 1e-7,.max_iterations = 10,.max_levels = 20
};

const graph_labelprop_params_t GRAPH_LABELPROP_DEFAULT = {
  .max_iterations = 10,
  .label_form = GRAPH_LABELPROP_LABELS_DENSE
};

const graph_clustering_params_t GRAPH_CLUSTERING_DEFAULT = {
  .directed = false
};

const graph_kmeans_params_t GRAPH_KMEANS_DEFAULT = {
  .k = 5,.max_iterations = 100,.epsilon = 1e-6,.seed = 42
};

#define WS_ALIGN(x) GRAPH_ALIGN_UP(x, GRAPH_CACHE_LINE_SIZE)

/* Node mapping */
static uint64_t
adv_build_node_map (const graph_snapshot_t *s, graph_node_id_t *nm, uint64_t cap)
{
  return graph_snapshot_copy_node_map (s, nm, cap);
}

/* Neighbour iteration is graph_neighbor.h's, addressing rows by node index.
 * This file used to carry its own copy, adv_nb_*, keyed by node id -- and
 * with it a thread-local snapshot and an adv_find_idx() whose whole job was
 * to undo that: the traversals here queued node *ids* and then resolved
 * each one back to the index it had been derived from.  They queue indices
 * now, so both are gone. */

/* adv_cnt_nb() was here.  It was extern for graph_algo_community.c, which
 * had its own identical copy anyway and now shares this file's iterator
 * instead, and nothing in this file ever called it. */

/* Bitmap */
GRAPH_INLINE void
adv_bm_set (uint64_t *b, uint64_t i)
{
  b[i >> 6] |= (1ULL << (i & 63));
}

GRAPH_INLINE bool
adv_bm_test (const uint64_t *b, uint64_t i)
{
  return (b[i >> 6] & (1ULL << (i & 63))) != 0;
}

GRAPH_INLINE void
adv_bm_clear (uint64_t *b, uint64_t w)
{
  memset (b, 0, w * sizeof (uint64_t));
}

/* Per-worker block for parallel betweenness: a private score row, then the
 * same per-source scratch the sequential loop uses. */
#define BTW_WORKER_STRIDE(V) \
    (WS_ALIGN((V) * sizeof(double)) * 3 + WS_ALIGN((V) * sizeof(uint64_t)) * 3 + \
     WS_ALIGN((V) * sizeof(int64_t)))

/* Betweenness centrality */
size_t
graph_algo_betweenness_workspace_size (const graph_snapshot_t *s)
{
  if (!s)
    return 0;
  uint64_t V = s->node_count > 0 ? s->node_count : 1;
  size_t sz = WS_ALIGN (sizeof (graph_workspace_header_t));
  sz += WS_ALIGN (V * sizeof (double)) * 2 + WS_ALIGN (V * sizeof (uint64_t)) + WS_ALIGN (V * sizeof (int64_t));
  sz += WS_ALIGN (V * sizeof (graph_node_id_t)) * 3 + WS_ALIGN (((V + 63) / 64) * sizeof (uint64_t));
  /* Per-worker blocks for the parallel pass: a private score row plus the
   * per-source scratch (sigma, dist, delta, queue, stack).  W*V doubles,
   * not V*V: workers take disjoint slices of the source loop and reduce
   * afterwards, so one row per worker is enough. */
  sz += (size_t) graph_parallel_worker_count () * BTW_WORKER_STRIDE (V);
  return sz;
}

/* Betweenness accumulates one contribution per source into a shared score
 * array, and floating-point addition is not associative, so summing in
 * worker order rather than source order changes the last bits of every
 * score.  The sequential order is therefore the default and stays exactly
 * as it was.
 *
 * Mode 1 slices the source loop across workers with a private score row
 * each and reduces in fixed worker order: deterministic for a given worker
 * count, and NOT bit-identical to mode 0.  Same trade, same wording, as
 * [Graph] PageRankGather 2. */
static int s_btw_parallel = 0;
void
graph_algo_set_betweenness_parallel (int mode)
{
  s_btw_parallel = (mode > 0) ? 1 : 0;
}

int
graph_algo_betweenness_parallel (void)
{
  return s_btw_parallel;
}

/* Betweenness centrality
 *
 * Unlike closeness, betweenness stays sequential on purpose: scores[]
 * accumulates one delta row per source across ALL sources, and adding
 * those floating-point contributions in worker order instead of source
 * order changes the rounding.  Bit-identical parallelism would need a
 * private score row per source (V*V doubles), so the Brandes loop keeps
 * its single-threaded source order. */
/* One source's Brandes pass, accumulating into scores[].  Shared by the
 * sequential loop and the parallel slice so both run the same arithmetic in
 * the same order within a source; only the order sources are summed in
 * differs between them. */
static void
btw_one_source (const graph_snapshot_t *snap, const graph_pred_filter_t *pf,
    uint64_t nc, graph_direction_t fwd_dir, graph_direction_t bwd_dir,
    uint64_t s, uint64_t *sigma, int64_t *dist, double *delta, uint64_t *queue, uint64_t *stack, double *scores)
{
  for (uint64_t i = 0; i < nc; i++)
    {
      sigma[i] = 0;
      dist[i] = -1;
      delta[i] = 0.0;
    }
  sigma[s] = 1;
  dist[s] = 0;
  uint64_t qh = 0, qt = 0, st = 0;
  queue[qt++] = s;
  while (qh < qt)
    {
      uint64_t v = queue[qh++];
      stack[st++] = v;
      neighbor_ctx_t ctx;
      neighbor_init_at (&ctx, snap, v, fwd_dir, pf);
      NEIGHBOR_FOREACH (ctx, w,
	  {
	    if (dist[w] < 0)
	    {
	    queue[qt++] = w; dist[w] = dist[v] + 1;}
	  if (dist[w] == dist[v] + 1) sigma[w] += sigma[v];}
      );
    }
  while (st > 0)
    {
      uint64_t w = stack[--st];
      neighbor_ctx_t ctx;
      neighbor_init_at (&ctx, snap, w, bwd_dir, pf);
      NEIGHBOR_FOREACH (ctx, v,
	  {
	  if (dist[v] == dist[w] - 1) delta[v] += ((double) sigma[v] / sigma[w]) * (1.0 + delta[w]);});
      if (w != s)
	scores[w] += delta[w];
    }
}

typedef struct btw_slice_ctx
{
  const graph_snapshot_t *snap;
  const graph_pred_filter_t *pf;
  uint64_t nc;
  uint64_t V;
  graph_direction_t fwd_dir, bwd_dir;
  uint8_t *blocks;		/* nw blocks of BTW_WORKER_STRIDE(V) */
} btw_slice_ctx_t;

static void
btw_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  btw_slice_ctx_t *c = (btw_slice_ctx_t *) arg;
  uint8_t *b = c->blocks + (size_t) worker_index * BTW_WORKER_STRIDE (c->V);
  double *scores = (double *) b;
  b += WS_ALIGN (c->V * sizeof (double));
  double *delta = (double *) b;
  b += WS_ALIGN (c->V * sizeof (double));
  /* one spare double row keeps the stride arithmetic simple */
  b += WS_ALIGN (c->V * sizeof (double));
  uint64_t *sigma = (uint64_t *) b;
  b += WS_ALIGN (c->V * sizeof (uint64_t));
  uint64_t *queue = (uint64_t *) b;
  b += WS_ALIGN (c->V * sizeof (uint64_t));
  uint64_t *stack = (uint64_t *) b;
  b += WS_ALIGN (c->V * sizeof (uint64_t));
  int64_t *dist = (int64_t *) b;
  for (uint64_t s = start; s < end; s++)
    btw_one_source (c->snap, c->pf, c->nc, c->fwd_dir, c->bwd_dir, s, sigma, dist, delta, queue, stack, scores);
}

graph_error_t
graph_algo_betweenness (const graph_snapshot_t *snap, const graph_betweenness_params_t *params,
    const graph_pred_filter_t *pf, void *ws, graph_betweenness_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  const graph_betweenness_params_t *p = params ? params : &GRAPH_BETWEENNESS_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->node_count = 0;
      return GRAPH_OK;
    }

  char *wp = (char *) ws;
  wp += WS_ALIGN (sizeof (graph_workspace_header_t));
  double *scores = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  double *delta = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  uint64_t *sigma = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  int64_t *dist = (int64_t *) wp;
  wp += WS_ALIGN (V * sizeof (int64_t));
  /* queue and stack hold node *indices*.  They held ids, and every
   * dequeue then searched the snapshot hash for the index the value had
   * been derived from one push earlier. */
  uint64_t *queue = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  uint64_t *stack = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  graph_node_id_t *node_map = (graph_node_id_t *) wp;

  uint64_t nc = adv_build_node_map (snap, node_map, V);
  memset (scores, 0, nc * sizeof (double));

  /* Determine direction based on params: directed uses OUTGOING/INCOMING, undirected uses BOTH */
  graph_direction_t fwd_dir = p->directed ? GRAPH_DIR_OUTGOING : GRAPH_DIR_BOTH;
  graph_direction_t bwd_dir = p->directed ? GRAPH_DIR_INCOMING : GRAPH_DIR_BOTH;

  if (s_btw_parallel && nc > 1)
    {
      btw_slice_ctx_t bc;
      graph_parallel_session_t *par;
      uint32_t nw = graph_parallel_worker_count (), wi;
      size_t stride = BTW_WORKER_STRIDE (V);
      bc.snap = snap;
      bc.pf = pf;
      bc.nc = nc;
      bc.fwd_dir = fwd_dir;
      bc.bwd_dir = bwd_dir;
      bc.blocks = (uint8_t *) node_map + WS_ALIGN (V * sizeof (graph_node_id_t));
      bc.V = V;
      for (wi = 0; wi < nw; wi++)
	memset (bc.blocks + (size_t) wi * stride, 0, WS_ALIGN (V * sizeof (double)));
      par = graph_parallel_begin (nc, GRAPH_PARALLEL_MAX_WORKERS);
      graph_parallel_run (par, 0, nc, btw_slice, &bc);
      graph_parallel_end (par);
      /* Reduce in worker order, which is fixed for a given worker count:
       * deterministic, and deliberately not bit-identical to mode 0. */
      for (wi = 0; wi < nw; wi++)
	{
	  const double *row = (const double *) (bc.blocks + (size_t) wi * stride);
	  for (uint64_t i = 0; i < nc; i++)
	    scores[i] += row[i];
	}
    }
  else
    {
      for (uint64_t s = 0; s < nc; s++)
	btw_one_source (snap, pf, nc, fwd_dir, bwd_dir, s, sigma, dist, delta, queue, stack, scores);
    }
  /* For undirected graphs, divide by 2 since each path is counted twice */
  if (!p->directed)
    {
      for (uint64_t i = 0; i < nc; i++)
	scores[i] /= 2.0;
    }
  if (p->normalized && nc > 2)
    {
      double norm = (nc - 1) * (nc - 2);
      if (!p->directed)
	norm /= 2.0;		/* Undirected normalization factor */
      for (uint64_t i = 0; i < nc; i++)
	scores[i] /= norm;
    }
  double mx = 0, sm = 0;
  for (uint64_t i = 0; i < nc; i++)
    {
      sm += scores[i];
      if (scores[i] > mx)
	mx = scores[i];
    }
  r->scores = scores;
  r->node_count = nc;
  r->max_score = mx;
  r->avg_score = nc > 0 ? sm / nc : 0;
  return GRAPH_OK;
}

/* Closeness centrality
 *
 * One BFS per source node; source s's BFS writes only scores[s], so the
 * source loop is sliced across workers with per-worker dist/queue/
 * visited scratch.  Each worker's sums accumulate in the same fixed
 * order as the sequential loop (distances are integers, the harmonic
 * sum walks indices in order), so parallel and inline runs are
 * bit-identical.  Neighbor resolution goes through the snapshot hash
 * directly - worker threads must not touch the adv_snapshot
 * thread-local. */
size_t
graph_algo_closeness_workspace_size (const graph_snapshot_t *s)
{
  if (!s)
    return 0;
  uint64_t V = s->node_count > 0 ? s->node_count : 1;
  uint64_t bw = (V + 63) / 64;
  size_t sz = WS_ALIGN (sizeof (graph_workspace_header_t)) + WS_ALIGN (V * sizeof (double)) +
      WS_ALIGN (V * sizeof (uint64_t)) + WS_ALIGN (V * sizeof (graph_node_id_t)) +
      WS_ALIGN (bw * sizeof (uint64_t)) + WS_ALIGN (V * sizeof (graph_node_id_t));
  /* Per-worker BFS scratch blocks: dist, queue, visited bitmap. */
  sz += (size_t) graph_parallel_worker_count () *
      (WS_ALIGN (V * sizeof (uint64_t)) + WS_ALIGN (V * sizeof (graph_node_id_t)) + WS_ALIGN (bw * sizeof (uint64_t)));
  return sz;
}

typedef struct closeness_slice_ctx
{
  const graph_snapshot_t *snap;
  const graph_pred_filter_t *pf;
  const graph_node_id_t *node_map;
  uint64_t nc;
  uint64_t bw;
  bool harmonic;
  bool normalized;
  graph_direction_t direction;
  double *scores;
  uint8_t *blocks;		/* base of the per-worker scratch blocks */
  size_t dist_stride;		/* WS_ALIGN(V * sizeof(uint64_t)) */
  size_t list_stride;		/* WS_ALIGN(V * sizeof(graph_node_id_t)) */
} closeness_slice_ctx_t;

/* One BFS from source s, then s's closeness score.  Shared by the
 * parallel slice and the single-source entry point so both paths run
 * the same arithmetic in the same order - parallel and inline results
 * must stay bit-identical. */
static void
closeness_compute_one (const graph_snapshot_t *snap, const graph_pred_filter_t *pf,
    uint64_t nc, uint64_t bw,
    bool harmonic, bool normalized,
    graph_direction_t direction, uint64_t s, uint64_t *dist, uint64_t *queue, uint64_t *visited, double *out_score)
{
  adv_bm_clear (visited, bw);
  for (uint64_t i = 0; i < nc; i++)
    dist[i] = UINT64_MAX;
  dist[s] = 0;
  adv_bm_set (visited, s);
  uint64_t qh = 0, qt = 0, reached = 1, total = 0;
  queue[qt++] = s;
  while (qh < qt)
    {
      uint64_t v = queue[qh++];
      neighbor_ctx_t ctx;
      neighbor_init_at (&ctx, snap, v, direction, pf);
      NEIGHBOR_FOREACH (ctx, w,
	  {
	    if (!adv_bm_test (visited, w))
	    {
	    adv_bm_set (visited, w); dist[w] = dist[v] + 1; total += dist[w]; reached++; queue[qt++] = w;}
	  }
      );
    }
  if (harmonic)
    {
      double hs = 0;
      for (uint64_t i = 0; i < nc; i++)
	if (i != s && dist[i] != UINT64_MAX && dist[i] > 0)
	  hs += 1.0 / dist[i];
      /* The sum of reciprocals is already finite on a disconnected graph,
         which is the reason to reach for harmonic; dividing by n-1 puts it
         on 0..1 like the other normalized measures, and is what Neo4j GDS
         returns.  NetworkX does not divide, and neither did this. */
      if (normalized && nc > 1)
	hs /= (double) (nc - 1);
      *out_score = hs;
    }
  else
    {
      double sc = (total > 0 && reached > 1) ? (double) (reached - 1) / total : 0;
      if (normalized && nc > 1)
	sc *= (double) (reached - 1) / (nc - 1);
      *out_score = sc;
    }
}

static void
closeness_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  closeness_slice_ctx_t *c = (closeness_slice_ctx_t *) arg;
  uint8_t *b = c->blocks + (size_t) worker_index * (c->dist_stride + c->list_stride + WS_ALIGN (c->bw * sizeof (uint64_t)));
  uint64_t *dist = (uint64_t *) b;
  uint64_t *queue = (uint64_t *) (b + c->dist_stride);
  uint64_t *visited = (uint64_t *) (b + c->dist_stride + c->list_stride);

  for (uint64_t s = start; s < end; s++)
    closeness_compute_one (c->snap, c->pf, c->nc, c->bw,
	c->harmonic, c->normalized, c->direction, s, dist, queue, visited, &c->scores[s]);
}

graph_error_t
graph_algo_closeness (const graph_snapshot_t *snap, const graph_closeness_params_t *params,
    const graph_pred_filter_t *pf, void *ws, graph_closeness_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  const graph_closeness_params_t *p = params ? params : &GRAPH_CLOSENESS_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->node_count = 0;
      return GRAPH_OK;
    }

  uint64_t bw = (V + 63) / 64;
  char *wp = (char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t));
  double *scores = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  uint64_t *dist = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  uint64_t *queue = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  uint64_t *visited = (uint64_t *) wp;
  wp += WS_ALIGN (bw * sizeof (uint64_t));
  graph_node_id_t *node_map = (graph_node_id_t *) wp;
  wp += WS_ALIGN (V * sizeof (graph_node_id_t));
  /* The shared dist/queue/visited slots are part of the fixed layout
   * but the parallel pass below works in per-worker blocks instead. */
  (void) dist;
  (void) queue;
  (void) visited;

  uint64_t nc = adv_build_node_map (snap, node_map, V);

  /* Per-worker BFS scratch follows the shared arrays; the workspace is
   * sized for graph_parallel_worker_count() slots and a session can
   * only dispatch fewer, so worker_index always addresses a valid
   * block. */
  size_t dist_stride = WS_ALIGN (V * sizeof (uint64_t));
  size_t list_stride = WS_ALIGN (V * sizeof (graph_node_id_t));
  uint8_t *blocks = (uint8_t *) wp;

  graph_parallel_session_t *par = graph_parallel_begin (nc, GRAPH_PARALLEL_MAX_WORKERS);

  closeness_slice_ctx_t sctx;
  sctx.snap = snap;
  sctx.pf = pf;
  sctx.node_map = node_map;
  sctx.nc = nc;
  sctx.bw = bw;
  sctx.harmonic = p->harmonic;
  sctx.normalized = p->normalized;
  sctx.direction = p->direction;
  sctx.scores = scores;
  sctx.blocks = blocks;
  sctx.dist_stride = dist_stride;
  sctx.list_stride = list_stride;
  graph_parallel_run (par, 0, nc, closeness_slice, &sctx);
  graph_parallel_end (par);

  double mx = 0, sm = 0;
  for (uint64_t i = 0; i < nc; i++)
    {
      sm += scores[i];
      if (scores[i] > mx)
	mx = scores[i];
    }
  r->scores = scores;
  r->node_count = nc;
  r->max_score = mx;
  r->avg_score = nc > 0 ? sm / nc : 0;
  return GRAPH_OK;
}

/* Single-source closeness: one BFS from target_node instead of the full
 * all-sources pass - the per-node BIF dispatch used to run the O(V*(V+E))
 * batch per row just to read out one score.  Uses the shared
 * dist/queue/visited slots of the closeness workspace layout; the score
 * is bit-identical to the same node's entry in a full graph_algo_closeness()
 * run because both go through closeness_compute_one(). */
graph_error_t
graph_algo_closeness_single (const graph_snapshot_t *snap,
    const graph_closeness_params_t *params, const graph_pred_filter_t *pf, void *ws, graph_node_id_t target_node, double *out_score)
{
  if (!snap || !ws || !out_score)
    return GRAPH_ERR_NULL_PTR;
  const graph_closeness_params_t *p = params ? params : &GRAPH_CLOSENESS_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    return GRAPH_ERR_NOT_FOUND;

  uint64_t bw = (V + 63) / 64;
  char *wp = (char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t));
  wp += WS_ALIGN (V * sizeof (double));	/* scores, not needed here */
  uint64_t *dist = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  uint64_t *queue = (uint64_t *) wp;
  wp += WS_ALIGN (V * sizeof (uint64_t));
  uint64_t *visited = (uint64_t *) wp;
  wp += WS_ALIGN (bw * sizeof (uint64_t));
  graph_node_id_t *node_map = (graph_node_id_t *) wp;

  uint64_t nc = adv_build_node_map (snap, node_map, V);
  uint64_t s = graph_snapshot_find_node (snap, target_node);
  if (s >= nc)
    return GRAPH_ERR_NOT_FOUND;	/* includes UINT64_MAX */

  closeness_compute_one (snap, pf, nc, bw, p->harmonic, p->normalized, p->direction, s, dist, queue, visited, out_score);
  return GRAPH_OK;
}

/* Eigenvector centrality */
size_t
graph_algo_eigenvector_workspace_size (const graph_snapshot_t *s)
{
  if (!s)
    return 0;
  uint64_t V = s->node_count > 0 ? s->node_count : 1;
  return WS_ALIGN (sizeof (graph_workspace_header_t)) + WS_ALIGN (V * sizeof (double)) * 2 +
      WS_ALIGN (V * sizeof (graph_node_id_t));
}

/* Gather slice: scores_new[i] = sum of scores over node i's INCOMING
 * neighbors.  Each worker writes only its own slice, and the additions
 * into one element always happen in that node's in-edge order, so the
 * result is bit-identical inline or under any worker partition.  Neighbor
 * resolution goes through the snapshot hash directly - worker threads
 * must not touch the adv_snapshot thread-local. */
typedef struct eigen_gather_ctx
{
  const graph_snapshot_t *snap;
  const graph_pred_filter_t *pf;
  const graph_node_id_t *node_map;
  const double *scores;
  double *scores_new;
} eigen_gather_ctx_t;

static void
eigen_gather_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  (void) worker_index;
  eigen_gather_ctx_t *c = (eigen_gather_ctx_t *) arg;

  for (uint64_t i = start; i < end; i++)
    {
      /* acc starts at the node's own score, which makes the iteration
       * (I + A) rather than A.  The shift moves every eigenvalue up by
       * one and no eigenvector at all, so it cannot change an answer the
       * plain iteration already reached -- but it is what lets the
       * iteration reach one.  Power iteration needs a single eigenvalue
       * largest in modulus, and a directed cycle has several (the roots
       * of unity), so on A the iterate rotates until the cap and returns
       * mid-rotation.  On I + A those become 1 + a root of unity, whose
       * moduli differ, and it converges. */
      double acc = c->scores[i];
      neighbor_ctx_t ctx;
      neighbor_init_at (&ctx, c->snap, i, GRAPH_DIR_INCOMING, c->pf);
      NEIGHBOR_FOREACH (ctx, j,
	  {
	    acc += c->scores[j];
	  });
      c->scores_new[i] = acc;
    }
}

graph_error_t
graph_algo_eigenvector (const graph_snapshot_t *snap, const graph_eigenvector_params_t *params,
    const graph_pred_filter_t *pf, void *ws, graph_eigenvector_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  const graph_eigenvector_params_t *p = params ? params : &GRAPH_EIGENVECTOR_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->node_count = 0;
      r->converged = true;
      return GRAPH_OK;
    }

  char *wp = (char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t));
  double *scores = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  double *scores_new = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  graph_node_id_t *node_map = (graph_node_id_t *) wp;

  uint64_t nc = adv_build_node_map (snap, node_map, V);
  double iv = 1.0 / sqrt ((double) nc);
  for (uint64_t i = 0; i < nc; i++)
    scores[i] = iv;

  graph_parallel_session_t *par = graph_parallel_begin (nc, GRAPH_PARALLEL_MAX_WORKERS);

  int iter = 0;
  double res = 0;
  bool conv = false;
  for (; iter < p->max_iterations; iter++)
    {
      eigen_gather_ctx_t ctx = {
	.snap = snap,.pf = pf,.node_map = node_map,
	.scores = scores,.scores_new = scores_new
      };
      graph_parallel_run (par, 0, nc, eigen_gather_slice, &ctx);
      double norm = graph_l2_norm (scores_new, nc);
      if (norm > 0)
	for (uint64_t i = 0; i < nc; i++)
	  scores_new[i] /= norm;
      res = graph_l1_residual (scores_new, scores, nc);
      double *tmp = scores;
      scores = scores_new;
      scores_new = tmp;
      if (res < p->epsilon)
	{
	  conv = true;
	  break;
	}
    }
  graph_parallel_end (par);
  r->scores = scores;
  r->node_count = nc;
  r->iterations = iter;
  r->residual = res;
  r->converged = conv;
  return conv ? GRAPH_OK : GRAPH_ERR_CONVERGENCE;
}

/* Harmonic */
size_t
graph_algo_harmonic_workspace_size (const graph_snapshot_t *s)
{
  return graph_algo_closeness_workspace_size (s);
}

graph_error_t
graph_algo_harmonic (const graph_snapshot_t *s,
    const graph_closeness_params_t *params, const graph_pred_filter_t *pf, void *ws, graph_harmonic_result_t *r)
{
  /* Harmonic is closeness with a different summation, so it takes the
   * same parameter block; only the harmonic flag is not the caller's. */
  graph_closeness_params_t p = params ? *params : GRAPH_CLOSENESS_DEFAULT;
  p.harmonic = true;
  if (!params)
    p.normalized = false;
  graph_closeness_result_t cr;
  graph_error_t e = graph_algo_closeness (s, &p, pf, ws, &cr);
  if (e != GRAPH_OK)
    return e;
  r->scores = cr.scores;
  r->node_count = cr.node_count;
  r->max_score = cr.max_score;
  r->avg_score = cr.avg_score;
  return GRAPH_OK;
}

/* Jaccard similarity
 *
 * |A intersect B| / |A union B| over two *sets*.  What is in the set is the
 * mode's business; the counting below is the same for all of them, and it has
 * to be set counting rather than edge counting.  It was not: each side's size
 * came from the adjacency row length -- the number of edges -- while the
 * membership test went through a hash of neighbour nodes.  Where a node
 * reaches one object twice by two predicates the two disagree, so the union
 * was overstated and the overlap double counted; on the graph
 *
 *     a p1 x .  a p1 y .        A = {x, y}
 *     b p1 x .  b p2 x .        B = {x}
 *
 * that returned 1 -- identical -- where the answer is 1/2.  RDF_QUAD makes
 * (s,p,o) unique, so it could not happen under a predicate filter; with no
 * filter, which is the default, it is ordinary.
 *
 * Elements are collected, sorted and merged rather than hashed.  A hash would
 * need the (predicate, node) pairs of the keeping-the-predicate modes folded
 * into one machine word, and two distinct pairs folding together would be a
 * wrong answer arrived at silently.  Sorting costs O(d log d) against the
 * hash's O(d), on a degree rather than on the graph, and this is asked one
 * pair at a time. */

typedef struct jac_elem
{
  uint64_t tag;			/* 0 outgoing, 1 incoming; separates the two in mode 2 */
  uint64_t pred;		/* 0 in the predicate-discarding modes */
  uint64_t node;		/* the other end, as a snapshot index */
} jac_elem_t;

static int
jac_elem_cmp (const void *l, const void *r)
{
  const jac_elem_t *a = (const jac_elem_t *) l, *b = (const jac_elem_t *) r;
  if (a->tag != b->tag)
    return a->tag < b->tag ? -1 : 1;
  if (a->pred != b->pred)
    return a->pred < b->pred ? -1 : 1;
  if (a->node != b->node)
    return a->node < b->node ? -1 : 1;
  return 0;
}

/* One side's element set: walk the directions the mode asks for, keep what it
 * compares by, then sort and drop duplicates.  Returns the distinct count, or
 * UINT64_MAX if the buffer could not be grown. */
static uint64_t
jac_collect (const graph_snapshot_t *s, uint64_t node_ix,
    graph_jaccard_mode_t mode, const graph_pred_filter_t *pf, jac_elem_t **buf_io, uint64_t *cap_io)
{
  neighbor_ctx_t ctx;
  uint64_t n = 0, i, w;
  int pass, passes;
  bool keep_pred = (GRAPH_JACCARD_PAIRS_OUT == mode || GRAPH_JACCARD_PAIRS_BOTH == mode);
  bool both_ways = (GRAPH_JACCARD_PAIRS_BOTH == mode || GRAPH_JACCARD_NEIGHBOURS_BOTH == mode);

  passes = both_ways ? 2 : 1;
  for (pass = 0; pass < passes; pass++)
    {
      graph_direction_t dir = (0 == pass) ? GRAPH_DIR_OUTGOING : GRAPH_DIR_INCOMING;
      /* Mode 3 compares neighbours whichever way the edge runs, so both
       * passes carry the same tag and a node reached both ways is one
       * element.  Mode 2 compares statements, and "x knows me" is not the
       * statement "I know x", so the passes are tagged apart. */
      uint64_t tag = (GRAPH_JACCARD_PAIRS_BOTH == mode && 1 == pass) ? 1 : 0;
      if (keep_pred)
	neighbor_init_at_pred (&ctx, s, node_ix, dir, pf);
      else
	neighbor_init_at (&ctx, s, node_ix, dir, pf);
      NEIGHBOR_FOREACH (ctx, nb,
	  {
	    if (n == *cap_io)
	    {
	      uint64_t ncap = *cap_io ? *cap_io * 2 : 16;
	      jac_elem_t * nb2 = (jac_elem_t *) graph_alloc (&s->graph->allocator,
		  ncap * sizeof (jac_elem_t)); if (!nb2) return UINT64_MAX; if (*buf_io)
	      {
	      memcpy (nb2, *buf_io, n * sizeof (jac_elem_t));
		graph_free (&s->graph->allocator, *buf_io, *cap_io * sizeof (jac_elem_t));}
	    *buf_io = nb2; *cap_io = ncap;}
	  (*buf_io)[n].tag = tag;
	    (*buf_io)[n].pred = keep_pred ? (uint64_t) neighbor_pred (&ctx) : 0; (*buf_io)[n].node = nb; n++;}
      );
    }
  if (n < 2)
    return n;
  qsort (*buf_io, (size_t) n, sizeof (jac_elem_t), jac_elem_cmp);
  for (i = 1, w = 1; i < n; i++)
    if (jac_elem_cmp (&(*buf_io)[i], &(*buf_io)[w - 1]) != 0)
      (*buf_io)[w++] = (*buf_io)[i];
  return w;
}

graph_error_t
graph_algo_jaccard (const graph_snapshot_t *s, graph_node_id_t a, graph_node_id_t b,
    graph_direction_t dir, const graph_pred_filter_t *pf, graph_jaccard_mode_t mode, graph_jaccard_result_t *r)
{
  jac_elem_t *ea = NULL, *eb = NULL;
  uint64_t capa = 0, capb = 0, na, nb_n, i = 0, j = 0, inter = 0, u;
  uint64_t ai, bi;
  if (!s || !r)
    return GRAPH_ERR_NULL_PTR;
  if ((int) mode < 0 || (int) mode > GRAPH_JACCARD_MODE_MAX)
    return GRAPH_ERR_INVALID_PARAM;
  /* `dir` is the caller's when the mode does not fix one; modes 2 and 3
   * walk both and ignore it. */
  (void) dir;

  ai = graph_snapshot_find_node (s, a);
  bi = graph_snapshot_find_node (s, b);

  na = jac_collect (s, ai, mode, pf, &ea, &capa);
  nb_n = (UINT64_MAX == na) ? UINT64_MAX : jac_collect (s, bi, mode, pf, &eb, &capb);
  if (UINT64_MAX == na || UINT64_MAX == nb_n)
    {
      if (ea)
	graph_free (&s->graph->allocator, ea, capa * sizeof (jac_elem_t));
      if (eb)
	graph_free (&s->graph->allocator, eb, capb * sizeof (jac_elem_t));
      return GRAPH_ERR_OUT_OF_MEMORY;
    }

  while (i < na && j < nb_n)
    {
      int c = jac_elem_cmp (&ea[i], &eb[j]);
      if (c < 0)
	i++;
      else if (c > 0)
	j++;
      else
	{
	  inter++;
	  i++;
	  j++;
	}
    }
  if (ea)
    graph_free (&s->graph->allocator, ea, capa * sizeof (jac_elem_t));
  if (eb)
    graph_free (&s->graph->allocator, eb, capb * sizeof (jac_elem_t));

  u = na + nb_n - inter;
  r->intersection = inter;
  r->union_size = u;
  r->similarity = u > 0 ? (double) inter / u : 0;
  return GRAPH_OK;
}

graph_error_t
graph_algo_jaccard_batch (const graph_snapshot_t *s, const graph_node_id_t *a,
    const graph_node_id_t *b, uint64_t n, graph_direction_t d,
    const graph_pred_filter_t *pf, graph_jaccard_mode_t mode, double *out)
{
  if (!s || !a || !b || !out)
    return GRAPH_ERR_NULL_PTR;
  for (uint64_t i = 0; i < n; i++)
    {
      graph_jaccard_result_t r;
      graph_error_t e = graph_algo_jaccard (s, a[i], b[i], d, pf, mode, &r);
      if (e != GRAPH_OK)
	return e;
      out[i] = r.similarity;
    }
  return GRAPH_OK;
}

/* ============================================================================
 * WEIGHTED CENTRALITY ALGORITHMS
 * ============================================================================ */

/* Helper: get edge weight with fallback to 1.0 */
static double
get_edge_weight (graph_weight_func_t wf, void *ud, graph_node_id_t src, graph_pred_id_t pred, graph_node_id_t dst)
{
  if (!wf)
    return 1.0;
  return wf (src, pred, dst, ud);
}

/* Weighted closeness centrality using Dijkstra-style distances */
graph_error_t
graph_algo_closeness_weighted (const graph_snapshot_t *snap,
    const graph_closeness_params_t *params,
    const graph_pred_filter_t *pf, graph_weight_func_t weight_func, void *weight_user_data, void *ws, graph_closeness_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  if (!weight_func)
    return graph_algo_closeness (snap, params, pf, ws, r);

  const graph_closeness_params_t *p = params ? params : &GRAPH_CLOSENESS_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->node_count = 0;
      return GRAPH_OK;
    }

  uint64_t bw = (V + 63) / 64;
  char *wp = (char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t));
  double *scores = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  double *dist = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  graph_node_id_t *node_map = (graph_node_id_t *) wp;
  wp += WS_ALIGN (V * sizeof (graph_node_id_t));
  /* The visited set needs a bit per node, so it needs a bitmap: it was a
   * single uint64_t, which gave the first 64 node indices a bit each and
   * nothing to the rest.  `visited >> i` is undefined for i >= 64 and on
   * the usual hardware reads bit (i & 63), so node 64 shared node 0's
   * bit -- settling one marked the other visited, Dijkstra skipped a
   * node it still had to relax, and the distances came out wrong.  Wrong
   * rather than missing, which is why no caller ever noticed.
   *
   * The room comes from the unweighted layout this path shares: it fits
   * scores, dist and node_map into slots sized for scores, an integer
   * distance vector, a queue, a bitmap and node_map, so the queue and
   * bitmap slots are spare here -- see graph_algo_closeness_workspace_size,
   * which allocates for the larger of the two layouts either way. */
  uint64_t *visited = (uint64_t *) wp;

  uint64_t nc = adv_build_node_map (snap, node_map, V);

  for (uint64_t src = 0; src < nc; src++)
    {
      for (uint64_t i = 0; i < nc; i++)
	dist[i] = INFINITY;
      dist[src] = 0;

      /* Simple Dijkstra with linear scan (OK for moderate graphs) */
      adv_bm_clear (visited, bw);
      for (uint64_t iter = 0; iter < nc; iter++)
	{
	  uint64_t u = UINT64_MAX;
	  double min_d = INFINITY;
	  for (uint64_t i = 0; i < nc; i++)
	    {
	      if (dist[i] < min_d && !adv_bm_test (visited, i))
		{
		  min_d = dist[i];
		  u = i;
		}
	    }
	  if (u == UINT64_MAX || min_d == INFINITY)
	    break;
	  adv_bm_set (visited, u);

	  neighbor_ctx_t ctx;
	  neighbor_init_at (&ctx, snap, u, p->direction, pf);
	  uint64_t v;
	  while (neighbor_next (&ctx, &v))
	    {
	      if (v == UINT64_MAX)
		continue;
	      /* The weight function is keyed by id, so this is one of the
	       * few callers that asks the iterator for one. */
	      double w = get_edge_weight (weight_func, weight_user_data, node_map[u], 0,
		  neighbor_id (&ctx));
	      if (w < 0)
		w = 1.0;	/* Ignore negative weights */
	      double alt = dist[u] + w;
	      if (alt < dist[v])
		dist[v] = alt;
	    }
	}

      /* Calculate closeness score */
      if (p->harmonic)
	{
	  double hs = 0;
	  for (uint64_t i = 0; i < nc; i++)
	    if (i != src && dist[i] != INFINITY && dist[i] > 0)
	      hs += 1.0 / dist[i];
	  if (p->normalized && nc > 1)
	    hs /= (double) (nc - 1);
	  scores[src] = hs;
	}
      else
	{
	  double total = 0;
	  uint64_t reached = 0;
	  for (uint64_t i = 0; i < nc; i++)
	    {
	      if (i != src && dist[i] != INFINITY)
		{
		  total += dist[i];
		  reached++;
		}
	    }
	  scores[src] = (total > 0 && reached > 0) ? (double) reached / total : 0;
	  if (p->normalized && nc > 1)
	    scores[src] *= (double) reached / (nc - 1);
	}
    }

  double mx = 0, sm = 0;
  for (uint64_t i = 0; i < nc; i++)
    {
      sm += scores[i];
      if (scores[i] > mx)
	mx = scores[i];
    }
  r->scores = scores;
  r->node_count = nc;
  r->max_score = mx;
  r->avg_score = nc > 0 ? sm / nc : 0;
  return GRAPH_OK;
}

/* Weighted betweenness centrality using Dijkstra for shortest paths */
/* Are two path lengths the same length?
 *
 * Scaled to the magnitudes being compared rather than a fixed epsilon: a
 * constant 1e-10 is a different test on distances of 0.5 than on
 * distances of 500, and path lengths are whatever unit the caller's
 * weights are in.  The floor keeps it meaningful when both are near zero.
 *
 * This is a correctness-of-principle change and not a measured fix: on
 * the graphs checked against NetworkX it changed no value, because at
 * those magnitudes the two tests agree.  The remaining disagreement on
 * weights that are not exactly representable in binary lies elsewhere --
 * see the note in the test suite. */
static inline bool
bw_same_len (double a, double b)
{
  double m = fabs (a) > fabs (b) ? fabs (a) : fabs (b);
  return fabs (a - b) <= (m > 1.0 ? m * 4.0 * DBL_EPSILON : 4.0 * DBL_EPSILON);
}

graph_error_t
graph_algo_betweenness_weighted (const graph_snapshot_t *snap,
    const graph_betweenness_params_t *params,
    const graph_pred_filter_t *pf, graph_weight_func_t weight_func, void *weight_user_data, void *ws, graph_betweenness_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  if (!weight_func)
    return graph_algo_betweenness (snap, params, pf, ws, r);

  const graph_betweenness_params_t *p = params ? params : &GRAPH_BETWEENNESS_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->node_count = 0;
      return GRAPH_OK;
    }

  char *wp = (char *) ws;
  wp += WS_ALIGN (sizeof (graph_workspace_header_t));
  double *scores = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  double *delta = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  double *sigma = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  double *dist = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  graph_node_id_t *stack = (graph_node_id_t *) wp;
  wp += WS_ALIGN (V * sizeof (graph_node_id_t));
  graph_node_id_t *node_map = (graph_node_id_t *) wp;
  wp += WS_ALIGN (V * sizeof (graph_node_id_t));
  /* A bit per node, for the same reason the weighted closeness needs one:
   * this was a single uint64_t, which covered the first 64 node indices
   * and nothing beyond.  `visited >> i` is undefined for i >= 64 and on
   * the usual hardware reads bit (i & 63), so settling a high-index node
   * marked a low-index one visited -- and Brandes then accumulated over
   * paths that were not the shortest ones.  On a 100-node chain the
   * middle node came back more than a third low.
   *
   * graph_algo_betweenness_workspace_size already allocates a bitmap and
   * one more node-sized slot than this path uses, so the room is there
   * without resizing anything. */
  uint64_t *visited = (uint64_t *) wp;
  uint64_t bw = (V + 63) / 64;
  /* Read the graph the way the caller asked, as the unweighted form
   * already did.  This path used to hardcode OUTGOING and INCOMING and
   * so always answered the directed question, whatever it was asked --
   * which is half of why a weighted and an unweighted betweenness of one
   * graph were not comparable. */
  graph_direction_t fwd_dir = p->directed ? GRAPH_DIR_OUTGOING : GRAPH_DIR_BOTH;
  graph_direction_t bwd_dir = p->directed ? GRAPH_DIR_INCOMING : GRAPH_DIR_BOTH;

  uint64_t nc = adv_build_node_map (snap, node_map, V);
  memset (scores, 0, nc * sizeof (double));

  for (uint64_t s = 0; s < nc; s++)
    {
      for (uint64_t i = 0; i < nc; i++)
	{
	  sigma[i] = 0;
	  dist[i] = INFINITY;
	  delta[i] = 0.0;
	}
      sigma[s] = 1;
      dist[s] = 0;
      uint64_t st = 0;

      /* Dijkstra with path counting */
      adv_bm_clear (visited, bw);
      for (uint64_t iter = 0; iter < nc; iter++)
	{
	  uint64_t u = UINT64_MAX;
	  double min_d = INFINITY;
	  for (uint64_t i = 0; i < nc; i++)
	    {
	      if (dist[i] < min_d && !adv_bm_test (visited, i))
		{
		  min_d = dist[i];
		  u = i;
		}
	    }
	  if (u == UINT64_MAX || min_d == INFINITY)
	    break;
	  adv_bm_set (visited, u);
	  stack[st++] = u;

	  neighbor_ctx_t ctx;
	  neighbor_init_at (&ctx, snap, u, fwd_dir, pf);
	  uint64_t v;
	  while (neighbor_next (&ctx, &v))
	    {
	      if (v == UINT64_MAX)
		continue;
	      double w = get_edge_weight (weight_func, weight_user_data, node_map[u], 0,
		  neighbor_id (&ctx));
	      if (w < 0)
		w = 1.0;
	      double alt = dist[u] + w;
	      /* Ask "is this the same length?" before "is it shorter?".
	         Two routes of equal length are two different sums of the
	         same weights, so they can round a couple of ulps apart;
	         read the smaller of them as strictly shorter and the
	         path count collapses to one, taking the scores with it. */
	      if (alt < dist[v])
		{
		  if (isfinite (dist[v]) && bw_same_len (alt, dist[v]))
		    sigma[v] += sigma[u];
		  else
		    sigma[v] = sigma[u];
		  dist[v] = alt;
		}
	      else if (bw_same_len (alt, dist[v]))
		{
		  sigma[v] += sigma[u];
		}
	    }
	}

      /* Backpropagate dependencies */
      while (st > 0)
	{
	  uint64_t w = stack[--st];
	  neighbor_ctx_t ctx;
	  neighbor_init_at (&ctx, snap, w, bwd_dir, pf);
	  uint64_t v;
	  while (neighbor_next (&ctx, &v))
	    {
	      if (v == UINT64_MAX)
		continue;
	      double edge_w = get_edge_weight (weight_func, weight_user_data,
		  neighbor_id (&ctx), 0, node_map[w]);
	      if (edge_w < 0)
		edge_w = 1.0;
	      if (bw_same_len (dist[v] + edge_w, dist[w]))
		{
		  delta[v] += (sigma[v] / sigma[w]) * (1.0 + delta[w]);
		}
	    }
	  if (w != s)
	    scores[w] += delta[w];
	}
    }

  /* For undirected graphs, divide by 2 since each path is counted twice */
  if (!p->directed)
    {
      for (uint64_t i = 0; i < nc; i++)
	scores[i] /= 2.0;
    }
  if (p->normalized && nc > 2)
    {
      double norm = (nc - 1) * (nc - 2);
      if (!p->directed)
	norm /= 2.0;		/* Undirected normalization factor */
      for (uint64_t i = 0; i < nc; i++)
	scores[i] /= norm;
    }

  double mx = 0, sm = 0;
  for (uint64_t i = 0; i < nc; i++)
    {
      sm += scores[i];
      if (scores[i] > mx)
	mx = scores[i];
    }
  r->scores = scores;
  r->node_count = nc;
  r->max_score = mx;
  r->avg_score = nc > 0 ? sm / nc : 0;
  return GRAPH_OK;
}

/* Weighted eigenvector centrality using edge weights in accumulation */
graph_error_t
graph_algo_eigenvector_weighted (const graph_snapshot_t *snap,
    const graph_eigenvector_params_t *params,
    const graph_pred_filter_t *pf, graph_weight_func_t weight_func, void *weight_user_data, void *ws, graph_eigenvector_result_t *r)
{
  if (!snap || !ws || !r)
    return GRAPH_ERR_NULL_PTR;
  if (!weight_func)
    return graph_algo_eigenvector (snap, params, pf, ws, r);

  const graph_eigenvector_params_t *p = params ? params : &GRAPH_EIGENVECTOR_DEFAULT;
  uint64_t V = snap->node_count;
  if (V == 0)
    {
      r->node_count = 0;
      r->converged = true;
      return GRAPH_OK;
    }

  char *wp = (char *) ws + WS_ALIGN (sizeof (graph_workspace_header_t));
  double *scores = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  double *scores_new = (double *) wp;
  wp += WS_ALIGN (V * sizeof (double));
  graph_node_id_t *node_map = (graph_node_id_t *) wp;

  uint64_t nc = adv_build_node_map (snap, node_map, V);
  double iv = 1.0 / sqrt ((double) nc);
  for (uint64_t i = 0; i < nc; i++)
    scores[i] = iv;

  int iter = 0;
  double res = 0;
  bool conv = false;
  for (; iter < p->max_iterations; iter++)
    {
      /* the same I + A shift as the unweighted gather above */
      for (uint64_t i = 0; i < nc; i++)
	scores_new[i] = scores[i];
      for (uint64_t i = 0; i < nc; i++)
	{
	  neighbor_ctx_t ctx;
	  neighbor_init_at (&ctx, snap, i, GRAPH_DIR_INCOMING, pf);
	  uint64_t j;
	  while (neighbor_next (&ctx, &j))
	    {
	      if (j != UINT64_MAX)
		{
		  double w = get_edge_weight (weight_func, weight_user_data,
		      neighbor_id (&ctx), 0, node_map[i]);
		  if (w < 0)
		    w = 1.0;
		  scores_new[i] += scores[j] * w;
		}
	    }
	}
      double norm = graph_l2_norm (scores_new, nc);
      if (norm > 0)
	for (uint64_t i = 0; i < nc; i++)
	  scores_new[i] /= norm;
      res = graph_l1_residual (scores_new, scores, nc);
      double *tmp = scores;
      scores = scores_new;
      scores_new = tmp;
      if (res < p->epsilon)
	{
	  conv = true;
	  break;
	}
    }
  r->scores = scores;
  r->node_count = nc;
  r->iterations = iter;
  r->residual = res;
  r->converged = conv;
  return conv ? GRAPH_OK : GRAPH_ERR_CONVERGENCE;
}
