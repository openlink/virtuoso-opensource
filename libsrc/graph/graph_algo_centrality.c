/*
 *  graph_algo_centrality.c
 *
 *  Centrality algorithm implementations
 *
 *  Implements degree centrality and PageRank. These are fundamental
 *  centrality measures used to identify important nodes in graphs.
 *
 *  Performance characteristics:
 *    - Degree: O(V + E) time, O(V) space
 *    - PageRank: O(k × E) time, O(V) space (k = iterations)
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

#include "graph_algo.h"
#include "graph_internal.h"
#include "graph_neighbor.h"
#include "graph_optim.h"
#include "graph_reduce.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

/* ============================================================================
 * DEFAULT PAGERANK PARAMETERS
 * ============================================================================ */

const graph_pagerank_params_t GRAPH_PAGERANK_DEFAULT = {
  .damping = 0.85,
  .epsilon = 1e-6,
  .max_iterations = 100,
  .directed = true
};

/* ============================================================================
 * WORKSPACE ALIGNMENT
 * ============================================================================ */

#define WS_ALIGN(x) GRAPH_ALIGN_UP(x, GRAPH_CACHE_LINE_SIZE)

/* ============================================================================
 * NODE MAPPING (shared with graph_algo.c)
 * ============================================================================ */

static uint64_t
build_node_map_local (const graph_snapshot_t *snapshot, graph_node_id_t *node_map, uint64_t capacity)
{
  return graph_snapshot_copy_node_map (snapshot, node_map, capacity);
}

/* The thread-local snapshot this file used to stash here went with the
 * iterator: nothing resolves a neighbour id to an index any more, because
 * the iterator yields indices. */

/* Neighbour iteration is graph_neighbor.h's, addressing rows by node index.
 * This file used to carry its own copy, neighbor_iter_*, which took a node
 * id and searched the base store's sorted table of every node id for the
 * index its caller already held -- once per vertex per direction, per
 * PageRank iteration and per degree pass. */

static uint64_t
count_neighbors (const graph_snapshot_t *snapshot,
    uint64_t node_index, graph_direction_t direction, const graph_pred_filter_t *pred_filter)
{
  neighbor_ctx_t ctx;
  uint64_t count = 0, neighbor;

  neighbor_init_at (&ctx, snapshot, node_index, direction, pred_filter);
  /* Nothing is filtered out on the index-only walk, so the count is the
   * adjacency rows' lengths and there is no walk to do. */
  if (neighbor_remaining (&ctx, &count))
    return count;
  while (neighbor_next (&ctx, &neighbor))
    count++;
  return count;
}

/* ============================================================================
 * DEGREE CENTRALITY IMPLEMENTATION
 * ============================================================================ */

uint64_t
graph_algo_node_degree (const graph_snapshot_t *snapshot,
    graph_node_id_t node, graph_direction_t direction, const graph_pred_filter_t *pred_filter)
{
  if (!snapshot || !snapshot->graph)
    return 0;
  /* Compacted snapshot with no predicate filter: the CSR row lengths are
   * the answer, so there is nothing to count. */
  if (!snapshot->delta_head && !pred_filter)
    return graph_base_node_degree (snapshot->graph->base, node, direction);
  /* This one is called with an id -- it is the scalar BIF's entry point --
   * so it resolves the index here, once, rather than the iterator doing
   * it once per direction. */
  return count_neighbors (snapshot, graph_snapshot_find_node (snapshot, node), direction, pred_filter);
}

size_t
graph_algo_degree_workspace_size (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return 0;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    V = 1;

  size_t size = 0;
  size += WS_ALIGN (sizeof (graph_workspace_header_t));
  size += WS_ALIGN (V * sizeof (uint64_t));	/* out_degrees */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* in_degrees */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* total_degrees */
  size += WS_ALIGN (V * sizeof (graph_node_id_t));	/* node_map */

  return size;
}

/* Per-node counting loop.  Each worker writes only degrees[i] for its own
 * slice, so the partition cannot change any result. */
typedef struct degree_slice_ctx
{
  const graph_snapshot_t *snapshot;
  const graph_pred_filter_t *pred_filter;
  uint64_t *out_degrees;
  uint64_t *in_degrees;
  uint64_t *total_degrees;
  graph_direction_t direction;
} degree_slice_ctx_t;

static void
degree_count_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  (void) worker_index;
  degree_slice_ctx_t *c = (degree_slice_ctx_t *) arg;

  for (uint64_t i = start; i < end; i++)
    {
      uint64_t out = 0, in = 0;

      if (c->direction == GRAPH_DIR_OUTGOING || c->direction == GRAPH_DIR_BOTH)
	out = count_neighbors (c->snapshot, i, GRAPH_DIR_OUTGOING, c->pred_filter);

      if (c->direction == GRAPH_DIR_INCOMING || c->direction == GRAPH_DIR_BOTH)
	in = count_neighbors (c->snapshot, i, GRAPH_DIR_INCOMING, c->pred_filter);

      c->out_degrees[i] = out;
      c->in_degrees[i] = in;
      c->total_degrees[i] = out + in;
    }
}

graph_error_t
graph_algo_degree (const graph_snapshot_t *snapshot,
    graph_direction_t direction, const graph_pred_filter_t *pred_filter, void *workspace, graph_degree_result_t *result)
{
  if (!snapshot || !workspace || !result)
    return GRAPH_ERR_NULL_PTR;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    {
      result->node_count = 0;
      return GRAPH_OK;
    }

  char *ws_ptr = (char *) workspace;

  graph_workspace_header_t *header = (graph_workspace_header_t *) ws_ptr;
  ws_ptr += WS_ALIGN (sizeof (graph_workspace_header_t));

  uint64_t *out_degrees = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  uint64_t *in_degrees = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  uint64_t *total_degrees = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  graph_node_id_t *node_map = (graph_node_id_t *) ws_ptr;

  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = GRAPH_ALGO_DEGREE;
  header->node_capacity = V;

  uint64_t node_count = build_node_map_local (snapshot, node_map, V);

  degree_slice_ctx_t ctx = {
    .snapshot = snapshot,
    .pred_filter = pred_filter,
    .out_degrees = out_degrees,
    .in_degrees = in_degrees,
    .total_degrees = total_degrees,
    .direction = direction
  };

  graph_parallel_session_t *par = graph_parallel_begin (node_count, GRAPH_PARALLEL_MAX_WORKERS);
  graph_parallel_run (par, 0, node_count, degree_count_slice, &ctx);
  graph_parallel_end (par);

  /* Integer reductions in index order - order-independent, so they stay
   * exact regardless of how the counting was partitioned. */
  uint64_t max_out = 0, max_in = 0;
  uint64_t total_out = 0, total_in = 0;
  for (uint64_t i = 0; i < node_count; i++)
    {
      if (direction == GRAPH_DIR_OUTGOING || direction == GRAPH_DIR_BOTH)
	{
	  total_out += out_degrees[i];
	  if (out_degrees[i] > max_out)
	    max_out = out_degrees[i];
	}
      if (direction == GRAPH_DIR_INCOMING || direction == GRAPH_DIR_BOTH)
	{
	  total_in += in_degrees[i];
	  if (in_degrees[i] > max_in)
	    max_in = in_degrees[i];
	}
    }

  result->out_degrees = out_degrees;
  result->in_degrees = in_degrees;
  result->total_degrees = total_degrees;
  result->node_count = node_count;
  result->max_out_degree = max_out;
  result->max_in_degree = max_in;
  result->avg_out_degree = node_count > 0 ? (double) total_out / node_count : 0.0;
  result->avg_in_degree = node_count > 0 ? (double) total_in / node_count : 0.0;

  return GRAPH_OK;
}

/* ============================================================================
 * PAGERANK IMPLEMENTATION
 * 
 * Uses the power iteration method:
 *   PR(v) = (1-d)/N + d × Σ PR(u)/out_deg(u)  for all u → v
 * 
 * Where d = damping factor (typically 0.85)
 * ============================================================================ */

size_t
graph_algo_pagerank_workspace_size (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return 0;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    V = 1;

  size_t size = 0;
  size += WS_ALIGN (sizeof (graph_workspace_header_t));
  size += WS_ALIGN (V * sizeof (double));	/* scores */
  size += WS_ALIGN (V * sizeof (double));	/* scores_new */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* out_degrees */
  size += WS_ALIGN (V * sizeof (double));	/* contrib */
  size += WS_ALIGN (V * sizeof (graph_node_id_t));	/* node_map */

  return size;
}

/* Initialization pass: seed scores and count outgoing degrees.  Each
 * worker writes only its own slice of both arrays. */
typedef struct pr_init_slice_ctx
{
  const graph_snapshot_t *snapshot;
  const graph_pred_filter_t *pred_filter;
  double *scores;
  uint64_t *out_degrees;
  double initial_score;
  graph_direction_t degree_direction;
} pr_init_slice_ctx_t;

static void
pr_init_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  (void) worker_index;
  pr_init_slice_ctx_t *c = (pr_init_slice_ctx_t *) arg;

  for (uint64_t i = start; i < end; i++)
    {
      c->scores[i] = c->initial_score;
      c->out_degrees[i] = count_neighbors (c->snapshot, i, c->degree_direction, c->pred_filter);
    }
}

/*
 * Per-source contribution, computed once per iteration instead of once
 * per edge.  The gather below used to evaluate
 * damping * scores[src] / out_degrees[src] inside its inner loop, so a
 * vertex of degree d had its own contribution divided d times over, and
 * every edge paid a divide plus a second random load.  Precomputing it
 * costs one divide per vertex per iteration -- 633,432 instead of
 * 34,185,747 on the largest graph measured -- and leaves the gather with
 * one load and no arithmetic.
 *
 * The expression is unchanged, including its association: C evaluates
 * damping * scores[i] / deg[i] as (damping * scores[i]) / deg[i] either
 * way, so every term the gather adds has the same bits it had before.
 * A source of out-degree zero contributes 0.0 rather than being skipped,
 * which is the same sum: the accumulator starts at teleport +
 * dangling_contrib, neither of which can be negative zero for a damping
 * factor in [0,1], so adding +0.0 cannot change it.
 */
typedef struct pr_contrib_slice_ctx
{
  const uint64_t *out_degrees;
  const double *scores;
  double *contrib;
  double damping;
} pr_contrib_slice_ctx_t;

static void
pr_contrib_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  (void) worker_index;
  pr_contrib_slice_ctx_t *c = (pr_contrib_slice_ctx_t *) arg;

  for (uint64_t i = start; i < end; i++)
    {
      uint64_t deg = c->out_degrees[i];
      c->contrib[i] = deg ? c->damping * c->scores[i] / (double) deg : 0.0;
    }
}

/*
 * Gather pass (pull form).  Instead of scattering contributions from each
 * source, each destination collects damping * score(src) / out_deg(src)
 * over its INCOMING neighbors.  The accumulated value for scores_new[i]
 * therefore depends only on the order in which node i's in-edges are
 * visited - identical inline and under any worker partition - so the
 * iteration is bit-identical whether one or many threads run it.  A
 * cross-worker sum would depend on the partition, which is why the
 * gather form is used instead of parallel scatter.
 */
typedef struct pr_gather_slice_ctx
{
  const graph_snapshot_t *snapshot;
  const graph_pred_filter_t *pred_filter;
  const double *contrib;	/* damping * score / out_degree, per source */
  double *scores_new;
  double base;			/* teleport + dangling contribution */
  graph_direction_t gather_direction;
} pr_gather_slice_ctx_t;

/* How the gather reads a vertex's in-edges.  Three settings, because two
 * separate things were confounded and only measuring them apart said
 * which one mattered:
 *
 *   0  step the neighbour iterator once per edge, one accumulator.  The
 *      original, and the order every pinned PageRank value was taken in.
 *   1  read each row as a run and add it in the same order, still one
 *      accumulator.  Bit-identical to 0 -- same terms, same sequence,
 *      same association -- and it skips the per-edge iterator step.
 *      THE DEFAULT.
 *   2  the same runs with four independent accumulators, so four
 *      dependent add chains overlap.  NOT bit-identical: floating-point
 *      addition is not associative, so partial sums formed in a different
 *      order round differently.
 *
 * Measured at 633,432 nodes and 34,185,747 edges, snapshot warm,
 * alternating legs: 782/791 ms at 0, 340/342 at 1, 279/282 at 2.  So the
 * per-edge iterator step was 57% of the gather and costs nothing to
 * remove, and the four accumulators are a further 1.22x that costs
 * bit-identity -- which is why 1 is the default and 2 is not.  The full
 * table is in p8-vector-kernel.md.
 *
 * Mode 0 is kept because it is the only thing mode 1's bit-identity can
 * be checked against. */
static int s_pr_gather_mode = 1;
void
graph_algo_set_pagerank_gather (int mode)
{
  s_pr_gather_mode = (mode < 0) ? 0 : (mode > 2) ? 2 : mode;
}

int
graph_algo_pagerank_gather (void)
{
  return s_pr_gather_mode;
}

static void
pr_gather_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  (void) worker_index;
  pr_gather_slice_ctx_t *c = (pr_gather_slice_ctx_t *) arg;

  for (uint64_t i = start; i < end; i++)
    {
      double acc = c->base;

      neighbor_ctx_t ctx;

      neighbor_init_at (&ctx, c->snapshot, i, c->gather_direction, c->pred_filter);

      if (1 == s_pr_gather_mode)
	{
	  /* a0 starts at the teleport term, not at zero.  Mode 0 adds
	   * the contributions *into* base -- ((base + c0) + c1) + ...
	   * -- so an accumulator that started at zero and was added to
	   * base at the end would associate differently and round
	   * differently.  That is the whole of what makes mode 1
	   * bit-identical, and it is one initialiser.
	   *
	   * NEIGHBOR_FOREACH carries the fall-back for a walk that has
	   * no runs -- a predicate filter, a delta chain, a pending
	   * deletion -- and starts it from the same a0, so the two forms
	   * cannot disagree here either. */
	  double a0 = acc;
	  NEIGHBOR_FOREACH (ctx, src_idx,
	      {
		a0 += c->contrib[src_idx];
	      });
	  /* a0 itself rather than a0 folded through a tree of zeros:
	   * adding 0.0 leaves every finite value's bits alone but turns
	   * -0.0 into +0.0, and not relying on base never being -0.0 is
	   * cheaper than arguing that it cannot be. */
	  c->scores_new[i] = a0;
	  continue;
	}

      if (2 == s_pr_gather_mode)
	{
	  /* Four accumulators, written out rather than taken from
	   * NEIGHBOR_FOREACH: the macro hides the run, which is exactly
	   * what a multiple-accumulator reduction needs to see.  This is
	   * the one loop in the engine that wants the slice by hand, and
	   * it is not bit-identical to the other two anyway. */
	  const void *slice;
	  bool narrow;
	  uint32_t n;
	  double a0 = acc, a1 = 0.0, a2 = 0.0, a3 = 0.0;
	  bool by_run = false;
	  while (neighbor_next_run (&ctx, &slice, &narrow, &n))
	    {
	      uint32_t k = 0;
	      by_run = true;
	      for (; k + 4 <= n; k += 4)
		{
		  a0 += c->contrib[graph_ix_at (slice, narrow, k)];
		  a1 += c->contrib[graph_ix_at (slice, narrow, k + 1)];
		  a2 += c->contrib[graph_ix_at (slice, narrow, k + 2)];
		  a3 += c->contrib[graph_ix_at (slice, narrow, k + 3)];
		}
	      for (; k < n; k++)
		a0 += c->contrib[graph_ix_at (slice, narrow, k)];
	    }
	  if (by_run)
	    {
	      c->scores_new[i] = ((a0 + a1) + (a2 + a3));
	      continue;
	    }
	  /* No runs; fall through to the one-at-a-time form. */
	}

      {
	uint64_t src_idx;
	while (neighbor_next (&ctx, &src_idx))
	  {
	    if (src_idx == UINT64_MAX)
	      continue;
	    acc += c->contrib[src_idx];
	  }
      }

      c->scores_new[i] = acc;
    }
}

graph_error_t
graph_algo_pagerank (const graph_snapshot_t *snapshot,
    const graph_pagerank_params_t *params, const graph_pred_filter_t *pred_filter, void *workspace, graph_pagerank_result_t *result)
{
  if (!snapshot || !workspace || !result)
    return GRAPH_ERR_NULL_PTR;

  const graph_pagerank_params_t *p = params ? params : &GRAPH_PAGERANK_DEFAULT;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    {
      result->node_count = 0;
      result->iterations = 0;
      result->converged = true;
      return GRAPH_OK;
    }

  char *ws_ptr = (char *) workspace;

  graph_workspace_header_t *header = (graph_workspace_header_t *) ws_ptr;
  ws_ptr += WS_ALIGN (sizeof (graph_workspace_header_t));

  double *scores = (double *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (double));

  double *scores_new = (double *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (double));

  uint64_t *out_degrees = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  double *contrib = (double *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (double));

  graph_node_id_t *node_map = (graph_node_id_t *) ws_ptr;

  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = GRAPH_ALGO_PAGERANK;
  header->node_capacity = V;

  uint64_t node_count = build_node_map_local (snapshot, node_map, V);

  double damping = p->damping;
  double teleport = (1.0 - damping) / (double) node_count;
  double initial_score = 1.0 / (double) node_count;

  /* An undirected graph is held one direction per edge, so both the
   * degree and the gather have to walk both ways for the neighbourhood
   * to be symmetric.  Every vertex with an edge then has a neighbour
   * under BOTH, so the dangling set reduces to the isolated vertices. */
  graph_direction_t degree_dir = p->directed ? GRAPH_DIR_OUTGOING : GRAPH_DIR_BOTH;
  graph_direction_t gather_dir = p->directed ? GRAPH_DIR_INCOMING : GRAPH_DIR_BOTH;

  graph_parallel_session_t *par = graph_parallel_begin (node_count, GRAPH_PARALLEL_MAX_WORKERS);

  pr_init_slice_ctx_t init_ctx = {
    .snapshot = snapshot,
    .pred_filter = pred_filter,
    .scores = scores,
    .out_degrees = out_degrees,
    .initial_score = initial_score,
    .degree_direction = degree_dir
  };
  graph_parallel_run (par, 0, node_count, pr_init_slice, &init_ctx);

  int iterations = 0;
  double residual = 0.0;
  bool converged = false;

  for (int iter = 0; iter < p->max_iterations; iter++)
    {
      iterations++;

      /* Dangling mass and residual are O(V) index-order sums; keeping
       * them sequential preserves bit-identical results under any
       * partition, and they are negligible next to the O(E) gather. */
      double dangling_sum = 0.0;
      for (uint64_t i = 0; i < node_count; i++)
	{
	  if (out_degrees[i] == 0)
	    {
	      dangling_sum += scores[i];
	    }
	}
      double dangling_contrib = damping * dangling_sum / (double) node_count;

      pr_contrib_slice_ctx_t contrib_ctx = {
	.out_degrees = out_degrees,
	.scores = scores,
	.contrib = contrib,
	.damping = damping
      };
      graph_parallel_run (par, 0, node_count, pr_contrib_slice, &contrib_ctx);

      pr_gather_slice_ctx_t gather_ctx = {
	.snapshot = snapshot,
	.pred_filter = pred_filter,
	.contrib = contrib,
	.scores_new = scores_new,
	.base = teleport + dangling_contrib,
	.gather_direction = gather_dir
      };
      graph_parallel_run (par, 0, node_count, pr_gather_slice, &gather_ctx);

      residual = graph_l1_residual (scores_new, scores, node_count);

      double *tmp = scores;
      scores = scores_new;
      scores_new = tmp;

      if (residual < p->epsilon)
	{
	  converged = true;
	  break;
	}
    }

  graph_parallel_end (par);

  result->scores = scores;
  result->node_count = node_count;
  result->iterations = iterations;
  result->residual = residual;
  result->converged = converged;

  return converged ? GRAPH_OK : GRAPH_ERR_CONVERGENCE;
}

/* ============================================================================
 * WEIGHTED PAGERANK IMPLEMENTATION
 * ============================================================================ */

static double
get_pr_edge_weight (graph_weight_func_t wf, void *ud, graph_node_id_t src, graph_pred_id_t pred, graph_node_id_t dst)
{
  if (!wf)
    return 1.0;
  double w = wf (src, pred, dst, ud);
  return w > 0 ? w : 1.0;
}

graph_error_t
graph_algo_pagerank_weighted (const graph_snapshot_t *snapshot,
    const graph_pagerank_params_t *params,
    const graph_pred_filter_t *pred_filter,
    graph_weight_func_t weight_func, void *weight_user_data, void *workspace, graph_pagerank_result_t *result)
{
  if (!snapshot || !workspace || !result)
    return GRAPH_ERR_NULL_PTR;
  if (!weight_func)
    return graph_algo_pagerank (snapshot, params, pred_filter, workspace, result);

  const graph_pagerank_params_t *p = params ? params : &GRAPH_PAGERANK_DEFAULT;
  /* Same reading as the unweighted form: at directed 0 both the
   * degree and the traversal run over GRAPH_DIR_BOTH, which is an
   * undirected graph held one direction per edge.  These were
   * hardcoded OUTGOING, so `directed 0` was accepted, forwarded and
   * then ignored -- weighted PageRank answered the directed question
   * whatever it was asked. */
  graph_direction_t pr_dir = p->directed ? GRAPH_DIR_OUTGOING : GRAPH_DIR_BOTH;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    {
      result->node_count = 0;
      result->iterations = 0;
      result->converged = true;
      return GRAPH_OK;
    }

  char *ws_ptr = (char *) workspace;

  graph_workspace_header_t *header = (graph_workspace_header_t *) ws_ptr;
  ws_ptr += WS_ALIGN (sizeof (graph_workspace_header_t));

  double *scores = (double *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (double));

  double *scores_new = (double *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (double));

  double *out_weights = (double *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (double));

  graph_node_id_t *node_map = (graph_node_id_t *) ws_ptr;

  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = GRAPH_ALGO_PAGERANK;
  header->node_capacity = V;

  uint64_t node_count = build_node_map_local (snapshot, node_map, V);

  double initial_score = 1.0 / (double) node_count;
  for (uint64_t i = 0; i < node_count; i++)
    {
      scores[i] = initial_score;
      out_weights[i] = 0.0;

      neighbor_ctx_t ctx;
      uint64_t nb_idx;
      neighbor_init_at (&ctx, snapshot, i, pr_dir, pred_filter);
      /* The weighted form is the one caller here that genuinely wants the
       * neighbour's id, so it asks for it; the unweighted gather above
       * never does and never pays for one. */
      while (neighbor_next (&ctx, &nb_idx))
	{
	  double w = get_pr_edge_weight (weight_func, weight_user_data, node_map[i], 0,
	      neighbor_id (&ctx));
	  out_weights[i] += w;
	}
    }

  double damping = p->damping;
  double teleport = (1.0 - damping) / (double) node_count;

  int iterations = 0;
  double residual = 0.0;
  bool converged = false;

  for (int iter = 0; iter < p->max_iterations; iter++)
    {
      iterations++;

      double dangling_sum = 0.0;
      for (uint64_t i = 0; i < node_count; i++)
	{
	  if (out_weights[i] == 0)
	    {
	      dangling_sum += scores[i];
	    }
	}
      double dangling_contrib = damping * dangling_sum / (double) node_count;

      for (uint64_t i = 0; i < node_count; i++)
	{
	  scores_new[i] = teleport + dangling_contrib;
	}

      for (uint64_t src_idx = 0; src_idx < node_count; src_idx++)
	{
	  if (out_weights[src_idx] == 0)
	    continue;

	  graph_node_id_t src_node = node_map[src_idx];

	  neighbor_ctx_t ctx;
	  uint64_t dst_idx;

	  neighbor_init_at (&ctx, snapshot, src_idx, pr_dir, pred_filter);
	  while (neighbor_next (&ctx, &dst_idx))
	    {
	      if (dst_idx != UINT64_MAX)
		{
		  double edge_w = get_pr_edge_weight (weight_func, weight_user_data, src_node, 0,
		      neighbor_id (&ctx));
		  double contrib = damping * scores[src_idx] * edge_w / out_weights[src_idx];
		  scores_new[dst_idx] += contrib;
		}
	    }
	}

      residual = 0.0;
      residual = graph_l1_residual (scores_new, scores, node_count);

      double *tmp = scores;
      scores = scores_new;
      scores_new = tmp;

      if (residual < p->epsilon)
	{
	  converged = true;
	  break;
	}
    }

  result->scores = scores;
  result->node_count = node_count;
  result->iterations = iterations;
  result->residual = residual;
  result->converged = converged;

  return converged ? GRAPH_OK : GRAPH_ERR_CONVERGENCE;
}
