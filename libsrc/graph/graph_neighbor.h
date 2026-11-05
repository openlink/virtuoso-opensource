/*
 *  graph_neighbor.h
 *
 *  The neighbour iterator, shared by every algorithm
 *
 *  There were four copies of this: one per algorithm file.  They drifted,
 *  and the drift was not cosmetic -- graph_algo.c's copy had the
 *  index-only walk, the index-keyed row accessors and the O(1) resume
 *  while the other three still loaded a 16-byte edge record per edge and
 *  searched a 5 MB table of node ids per vertex for an index the caller
 *  already had.  BFS, WCC and Dijkstra were fast; PageRank, CDLP, LCC and
 *  the rest were not, for no reason other than which file they lived in.
 *
 *  So there is one copy, here, static inline: the algorithms call it in
 *  their hottest loops and every one of them is a separate translation
 *  unit.
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

#ifndef GRAPH_NEIGHBOR_H
#define GRAPH_NEIGHBOR_H

#include "graph_internal.h"
#include "graph_algo.h"

/* The index-only walk's switch.  Defined once in graph_algo.c and
 * declared here rather than being a static in this header: a static
 * would give every including file its own copy, and
 * GRAPH_SET_LIMIT('IndexWalk', 0) would then switch one algorithm's walk
 * and leave the others on the fast path -- which is a silent wrong
 * answer in the equality tests that exist to compare the two. */
extern bool graph_neighbor_index_walk;

/* ============================================================================
 * NEIGHBOR ITERATION (inline for performance)
 * ============================================================================ */

typedef struct neighbor_ctx
{
  const graph_snapshot_t *snapshot;
  graph_node_id_t node;
  graph_direction_t direction;
  const graph_pred_filter_t *pred_filter;

  /* The store, and each direction's row as its first absolute CSR slot.
   * Slot numbers rather than record pointers: a store whose edges all
   * carry one predicate holds no records, and a slot number is also
   * what indexes the endpoint slice and the per-slot weights. */
  const graph_base_store_t *base;
  uint64_t base_start;
  const void *base_target_ix;
  uint32_t base_count;
  uint32_t base_idx;

  uint64_t inv_start;
  const void *inv_source_ix;
  uint32_t inv_count;
  uint32_t inv_idx;

  /* Element width of the two slices above, copied off the store once so
   * the read sites do not have to reach back through the snapshot for
   * it.  See graph_ix_at() in graph_internal.h. */
  bool narrow_ix;

  graph_delta_t *delta;
  uint32_t delta_idx;

  /* Index of the neighbour just returned, UINT64_MAX when it came from a
   * delta and must be looked up in the snapshot hash. */
  uint64_t last_ix;
  bool use_ix;
  bool has_del;

  /* Weight of the edge just returned, when the caller supplied per-slot
   * weights and the edge came from the CSR.  A delta addition has no
   * slot, so last_weight_valid is false for one and the caller falls
   * back to its weight function.
   *
   * w_fwd / w_inv are sliced to this node's rows, the same way the
   * endpoint slices are: base_idx and inv_idx count within a row, not
   * across the whole CSR. */
  const double *w_fwd;
  const double *w_inv;
  double last_weight;
  bool last_weight_valid;

  /* Index-only walk: read the endpoint index out of the parallel array
   * and never touch graph_edge_t.
   *
   * last_id is the id of the neighbour just yielded when the walk had it
   * to hand -- the general walk reads it out of the edge record anyway.
   * On the index-only walk it is GRAPH_NODE_ID_INVALID and neighbor_id()
   * resolves it from node_ids on demand.  On demand matters: no
   * traversal in this file wants a neighbour's id on the fast path, so
   * resolving one per edge is a dependent random load into 5 MB whose
   * result is thrown away. */
  const graph_node_id_t *node_ids;
  graph_node_id_t last_id;
  /* Predicate of the edge just yielded, for a caller that compares by it
   * rather than only by where the edge lands.  Only the per-edge walk sets
   * it -- the run form hands back a slice of endpoints and never looks at a
   * predicate -- so neighbor_init_at_pred() clears `fast`, which is what
   * both neighbor_next_run() and the index-only path are gated on. */
  graph_pred_id_t last_pred;
  bool fast;
} neighbor_ctx_t;

/* Start a walk over one vertex's neighbours, addressing the vertex by its
 * *snapshot* node index -- the index into snapshot->node_map, which is what
 * every algorithm's arrays are keyed by and what neighbor_next() yields.
 *
 * The index, not the id.  Every traversal holds one -- the iterator hands
 * one back for each edge, and the source is resolved once per run -- and
 * addressing rows by id means paying graph_base_find_node_index() to search
 * a sorted table of every node id for something the caller already knows.
 * The id is still needed for the general walk's deletion test and delta
 * phase, and comes out of node_ids for free once the index is known.
 *
 * Snapshot index and base-store index are the same number when the
 * snapshot has no delta chain, which is the only shape the BIF surface
 * currently produces: a cache miss builds a fresh store, loads it, then
 * commits and compacts with no snapshot yet pinning the graph, so
 * delta_head is NULL and node_map is base->node_ids element for element.
 *
 * They are not the same number when a delta chain survives -- a delta can
 * name nodes the base store does not hold, and node_map is the sorted union
 * -- so the two are translated apart below rather than assumed equal.  The
 * assumption would hold today and fail silently later: node ids are handed
 * out increasing, so a delta's new nodes normally land at the end of
 * node_map and the prefix still lines up.  It takes an id minted before
 * this graph existed to shift the prefix, and then a vertex would be given
 * some other vertex's adjacency row and no test would say so. */
static inline void
neighbor_init_at (neighbor_ctx_t *ctx,
    const graph_snapshot_t *snapshot, uint64_t node_index, graph_direction_t direction, const graph_pred_filter_t *pred_filter)
{
  const graph_base_store_t *nbase = snapshot->graph ? snapshot->graph->base : NULL;
  graph_node_id_t node;
  uint64_t base_index = node_index;

  /* Translate snapshot index -> base index, when they can differ.  Costs
   * one taken branch on the walk that is already the slow one, and
   * nothing at all on the path that matters. */
  if (NULL != snapshot->delta_head)
    {
      node = (snapshot->node_map && node_index < snapshot->node_map_count) ? snapshot->node_map[node_index] : GRAPH_NODE_ID_INVALID;
      base_index = (GRAPH_NODE_ID_INVALID != node && nbase) ? graph_base_find_node_index (nbase, node) : UINT64_MAX;
    }
  else
    {
      node = (nbase && nbase->node_ids && node_index < nbase->node_count) ? nbase->node_ids[node_index] : GRAPH_NODE_ID_INVALID;
    }
  ctx->snapshot = snapshot;
  ctx->node = node;
  ctx->direction = direction;
  ctx->pred_filter = pred_filter;
  ctx->base_idx = 0;
  ctx->delta_idx = 0;
  ctx->inv_idx = 0;
  ctx->inv_start = 0;
  ctx->inv_source_ix = NULL;
  ctx->inv_count = 0;
  ctx->base_start = 0;
  ctx->base_target_ix = NULL;
  ctx->base_count = 0;
  ctx->last_ix = UINT64_MAX;
  ctx->last_pred = 0;
  /* The endpoint index arrays answer for the whole snapshot only when
   * every edge in it has a CSR slot, which is what "no delta chain"
   * means -- and only when the store actually has them.  A store loaded
   * from a file has the edges but not the indices, because the on-disk
   * format has never carried them; without the second half of this test
   * such a store would read a slice that is absent or the wrong length
   * and answer with whatever was there. */
  ctx->use_ix = (NULL == snapshot->delta_head) &&
      NULL != nbase && NULL != nbase->edge_targets && (!nbase->has_inverse || NULL != nbase->inv_sources);
  ctx->has_del = graph_chain_has_deletions (snapshot->delta_head);
  ctx->w_fwd = NULL;
  ctx->w_inv = NULL;
  ctx->last_weight = 0.0;
  ctx->last_weight_valid = false;
  ctx->node_ids = NULL;
  ctx->last_id = GRAPH_NODE_ID_INVALID;
  ctx->fast = false;

  const graph_base_store_t *base = snapshot->graph->base;
  ctx->base = base;
  ctx->narrow_ix = base->narrow_ix;
  /* GRAPH_DIR_BOTH needs both arrays.  Fetching only the outgoing one
   * here is what made an undirected traversal silently follow out-edges
   * only.  Same shape as comm_nb_init() in graph_algo_community.c. */
  if (direction == GRAPH_DIR_OUTGOING || direction == GRAPH_DIR_BOTH)
    {
      graph_base_get_edges_at (base, base_index, &ctx->base_start, &ctx->base_target_ix, &ctx->base_count);
    }
  if (direction == GRAPH_DIR_INCOMING || direction == GRAPH_DIR_BOTH)
    {
      graph_base_get_inverse_edges_at (base, base_index, &ctx->inv_start, &ctx->inv_source_ix, &ctx->inv_count);
    }
  ctx->delta = snapshot->delta_head;

  /* Every reason the general walk exists, stated as the conditions that
   * rule the index-only one out:
   *
   *   pred_filter        a filter has to be tested per edge, and the
   *                      predicate is per edge unless the store holds
   *                      only one.  With no filter pred_matches()
   *                      returns true for every edge, so skipping it is
   *                      not an approximation.
   *   !use_ix            a delta chain holds edges with no slot, and the
   *                      index arrays do not cover them.  It is also
   *                      what makes the delta phase below reachable, so
   *                      the fast walk need not have one.
   *   has_del            is_deleted() builds a triple to test, and needs
   *                      the predicate to build it.
   *   missing arrays     a store built without them.
   *
   * node_ids[edge_targets[at]] is edges[at].object exactly: the index
   * was resolved from that object against this same sorted table when
   * the CSR was built.  Same for inv_sources and subject. */
  ctx->node_ids = base->node_ids;
  ctx->fast = graph_neighbor_index_walk && NULL == pred_filter && ctx->use_ix &&
      !ctx->has_del && NULL != base->node_ids &&
      (0 == ctx->base_count || NULL != ctx->base_target_ix) && (0 == ctx->inv_count || NULL != ctx->inv_source_ix);
}

/* As neighbor_init_at(), and additionally resolve each yielded edge's weight
 * out of the per-slot arrays.  The arrays are indexed by the CSR slot, so
 * they are only usable while the snapshot's edges all come from the CSR --
 * a delta addition has no slot and falls through to the caller's weight
 * function. */
static inline void
neighbor_init_weighted_at (neighbor_ctx_t *ctx,
    const graph_snapshot_t *snapshot,
    uint64_t node_index, graph_direction_t direction, const graph_pred_filter_t *pred_filter, const graph_edge_weights_t *weights)
{
  const graph_base_store_t *base;

  neighbor_init_at (ctx, snapshot, node_index, direction, pred_filter);
  if (!weights || !weights->fwd || !ctx->use_ix)
    return;
  /* The arrays are indexed by CSR slot, so one sized for a different
   * CSR is not merely stale, it is out of bounds.  Refusing it here is
   * what makes the slot loads in neighbor_next() unchecked. */
  if (!snapshot->graph || !snapshot->graph->base)
    return;
  base = snapshot->graph->base;
  if (weights->count != base->edge_count)
    return;
  /* Slice to this node's rows.  base_idx and inv_idx count within a row,
   * so the weights are offset by the row's first slot -- reading the
   * global array at a row-relative index gives some other edge's
   * weight, which is a wrong answer rather than a crash. */
  if (ctx->base_count)
    ctx->w_fwd = weights->fwd + ctx->base_start;
  if (ctx->inv_count && weights->inv)
    ctx->w_inv = weights->inv + ctx->inv_start;
}

static inline bool
pred_matches (const graph_pred_filter_t *filter, graph_pred_id_t pred)
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

static inline bool
is_deleted (const graph_snapshot_t *snapshot, const graph_triple_t *t)
{
  graph_delta_t *d = snapshot->delta_head;
  while (d)
    {
      if (graph_delta_contains_deletion (d, t))
	return true;
      d = d->prev;
    }
  return false;
}

/* Yield the next neighbour as its node index, or UINT64_MAX when the
 * snapshot cannot place it (a delta addition naming a node the base store
 * does not hold).  neighbor_id() gives the id if the caller wants one. */
static inline bool
neighbor_next (neighbor_ctx_t *ctx, uint64_t *out_ix)
{
  /* Three phases: outgoing base edges, incoming base edges, delta
   * additions.  neighbor_init_at() only populates the arrays the direction
   * asks for, so a single-direction walk skips the phase it does not
   * want without a test here. */

  /* The index-only walk.  Two phases rather than three -- ctx->fast
   * implies use_ix, which implies there is no delta chain to walk. */
  if (ctx->fast)
    {
      while (ctx->base_idx < ctx->base_count)
	{
	  uint32_t at = ctx->base_idx++;
	  ctx->last_ix = *out_ix = graph_ix_at (ctx->base_target_ix, ctx->narrow_ix, at);
	  if (ctx->w_fwd)
	    {
	      ctx->last_weight = ctx->w_fwd[at];
	      ctx->last_weight_valid = true;
	    }
	  return true;
	}
      while (ctx->inv_idx < ctx->inv_count)
	{
	  uint32_t at = ctx->inv_idx++;
	  ctx->last_ix = *out_ix = graph_ix_at (ctx->inv_source_ix, ctx->narrow_ix, at);
	  if (ctx->w_inv)
	    {
	      ctx->last_weight = ctx->w_inv[at];
	      ctx->last_weight_valid = true;
	    }
	  else
	    {
	      ctx->last_weight_valid = false;
	    }
	  return true;
	}
      return false;
    }

  /* Outgoing base edges */
  while (ctx->base_idx < ctx->base_count)
    {
      uint32_t at = ctx->base_idx++;
      graph_pred_id_t e_pred = graph_base_slot_pred (ctx->base, ctx->base_start + at);
      graph_node_id_t e_obj = graph_base_slot_obj (ctx->base, ctx->base_start + at);

      if (!pred_matches (ctx->pred_filter, e_pred))
	continue;

      if (ctx->has_del)
	{
	  graph_triple_t t = { ctx->node, e_pred, e_obj };
	  if (is_deleted (ctx->snapshot, &t))
	    continue;
	}

      ctx->last_pred = e_pred;
      ctx->last_id = e_obj;
      ctx->last_ix = ctx->use_ix
	  ? graph_ix_at (ctx->base_target_ix, ctx->narrow_ix, at) : graph_snapshot_find_node (ctx->snapshot, e_obj);
      *out_ix = ctx->last_ix;
      if (ctx->w_fwd)
	{
	  ctx->last_weight = ctx->w_fwd[at];
	  ctx->last_weight_valid = true;
	}
      return true;
    }

  /* Incoming base edges, via the inverse index and its own index array */
  while (ctx->inv_idx < ctx->inv_count)
    {
      uint32_t at = ctx->inv_idx++;
      graph_pred_id_t e_pred = graph_base_inv_slot_pred (ctx->base, ctx->inv_start + at);
      graph_node_id_t e_subj = graph_base_inv_slot_subj (ctx->base, ctx->inv_start + at);

      if (!pred_matches (ctx->pred_filter, e_pred))
	continue;

      if (ctx->has_del)
	{
	  graph_triple_t t = { e_subj, e_pred, ctx->node };
	  if (is_deleted (ctx->snapshot, &t))
	    continue;
	}

      ctx->last_pred = e_pred;
      ctx->last_id = e_subj;
      ctx->last_ix = ctx->use_ix
	  ? graph_ix_at (ctx->inv_source_ix, ctx->narrow_ix, at) : graph_snapshot_find_node (ctx->snapshot, e_subj);
      *out_ix = ctx->last_ix;
      if (ctx->w_inv)
	{
	  ctx->last_weight = ctx->w_inv[at];
	  ctx->last_weight_valid = true;
	}
      else
	{
	  ctx->last_weight_valid = false;
	}
      return true;
    }

  /* Delta additions */
  while (ctx->delta)
    {
      while (ctx->delta_idx < ctx->delta->addition_count)
	{
	  const graph_triple_t *t = &ctx->delta->additions[ctx->delta_idx++];

	  if (ctx->direction == GRAPH_DIR_OUTGOING && t->subject != ctx->node)
	    continue;
	  if (ctx->direction == GRAPH_DIR_INCOMING && t->object != ctx->node)
	    continue;
	  if (ctx->direction == GRAPH_DIR_BOTH && t->subject != ctx->node && t->object != ctx->node)
	    continue;
	  if (!pred_matches (ctx->pred_filter, t->predicate))
	    continue;

	  ctx->last_pred = t->predicate;
	  ctx->last_id = (t->subject == ctx->node) ? t->object : t->subject;
	  ctx->last_ix = *out_ix = graph_snapshot_find_node (ctx->snapshot, ctx->last_id);
	  ctx->last_weight_valid = false;
	  return true;
	}
      ctx->delta = ctx->delta->prev;
      ctx->delta_idx = 0;
    }

  return false;
}

/* Advance past the first n neighbours this walk would yield, without
 * yielding them.
 *
 * Only sound on the index-only walk.  There, nothing is filtered out and
 * the yielded sequence is simply the two adjacency rows concatenated, so
 * "the nth neighbour" is a position that can be jumped to.  On the general
 * walk the sequence is a filtered subsequence and the nth can only be
 * found by counting, which is what the caller falls back to.
 *
 * False means "I could not, count them yourself". */
static inline bool
neighbor_skip (neighbor_ctx_t *ctx, uint32_t n)
{
  if (!ctx->fast)
    return false;
  if (n <= ctx->base_count)
    {
      ctx->base_idx = n;
      return true;
    }
  ctx->base_idx = ctx->base_count;
  n -= ctx->base_count;
  ctx->inv_idx = (n > ctx->inv_count) ? ctx->inv_count : n;
  return true;
}

/* The next contiguous run of neighbour indices, as the slice it lives in
 * and how many entries of it are left, without yielding them one at a
 * time.  Two runs at most -- the outgoing row and the incoming row -- and
 * a caller that loops until this returns false has seen exactly what
 * neighbor_next() would have yielded, in the same order.
 *
 * Only the index-only walk has runs, for the reason neighbor_skip() is
 * limited to it: there, nothing is filtered out and no index can be
 * absent, so a run is a plain array segment.  On the general walk the
 * yielded sequence is a filtered subsequence of two arrays and there is
 * nothing contiguous to hand out.
 *
 * False means "I could not, walk them one at a time".  Exists so that a
 * reduction over a vertex's neighbours can be written with more than one
 * accumulator; whether that is worth doing is a separate question and the
 * answer for the PageRank gather is in p8-vector-kernel.md. */
static inline bool
neighbor_next_run (neighbor_ctx_t *ctx, const void **out_slice, bool *out_narrow, uint32_t *out_n)
{
  if (!ctx->fast)
    return false;
  *out_narrow = ctx->narrow_ix;
  if (ctx->base_idx < ctx->base_count)
    {
      *out_slice = graph_ix_slice (ctx->base_target_ix, ctx->narrow_ix, ctx->base_idx);
      *out_n = ctx->base_count - ctx->base_idx;
      ctx->base_idx = ctx->base_count;
      return true;
    }
  if (ctx->inv_idx < ctx->inv_count)
    {
      *out_slice = graph_ix_slice (ctx->inv_source_ix, ctx->narrow_ix, ctx->inv_idx);
      *out_n = ctx->inv_count - ctx->inv_idx;
      ctx->inv_idx = ctx->inv_count;
      return true;
    }
  return false;
}

/* How many neighbours this walk still has to yield, without walking them.
 *
 * Sound only on the index-only walk, for the reason neighbor_skip() is:
 * there, nothing is filtered out and the remaining sequence is just what
 * is left of the two adjacency rows.  On the general walk the yielded
 * sequence is a filtered subsequence whose length is not known until it
 * has been produced.
 *
 * False means "I could not, count them yourself". */
static inline bool
neighbor_remaining (const neighbor_ctx_t *ctx, uint64_t *out)
{
  if (!ctx->fast)
    return false;
  *out = (uint64_t) (ctx->base_count - ctx->base_idx) + (uint64_t) (ctx->inv_count - ctx->inv_idx);
  return true;
}

/* Walk one vertex's neighbours by run where the walk has runs, and one at
 * a time where it does not, with the body written once.
 *
 *      NEIGHBOR_FOREACH (ctx, ix, { acc += scores[ix]; });
 *
 * `ix` is declared by the macro -- do not declare it yourself -- and is
 * the neighbour's snapshot node index, the same number neighbor_next()
 * yields.  `ctx` must already be initialised by neighbor_init_at() or
 * neighbor_init_weighted_at().
 *
 * WHY THIS EXISTS, AND WHY IT IS A MACRO
 *
 * neighbor_next_run() only works on the index-only walk: it returns false
 * when there is a predicate filter, a delta chain, a pending deletion or
 * no index arrays.  So every loop that wants runs needs *both* forms, the
 * run loop and the per-edge fall-back, and PageRank's conversion turned
 * four lines into nine.  Writing that out at the twenty-odd sites that
 * want it would double the text of every traversal in the engine and give
 * twenty-odd chances for the two forms to drift -- which is the fault the
 * single neighbour iterator in this file exists to have ended, arriving
 * from a different direction.
 *
 * The stronger reason is memory safety.  neighbor_next_run() hands back a
 * raw slice pointer, an element width and a count; every hand-written
 * consumer re-writes the bounds arithmetic, and an off-by-one there is not
 * a crash but an *answer* -- the slice points into the CSR, so reading one
 * past a row returns the next row's endpoint and the algorithm carries on.
 * That arithmetic is written once, here, and reviewed once.
 *
 * `continue` IS SAFE.  `break` IS NOT.
 *
 * `continue` skips one edge in both forms, which is the same thing in
 * both.  `break` is not: in the run form it would leave the inner loop
 * over the slice and then carry on with the *next* run, which is a silent
 * wrong answer rather than an error.  A body that needs to stop early must
 * use neighbor_next() directly.
 *
 * Four bodies in the engine do, and all four are excluded from the run
 * form on other grounds anyway, so this is a rule to keep rather than one
 * to enforce today: graph_algo.c's depth-first walk and both of its
 * strongly-connected-components walks resume through neighbor_skip() and
 * an edge index, and its weighted relaxation needs a per-edge weight that
 * a run does not carry.
 *
 * WHY THE RUN FORM DOES NOT TEST FOR AN ABSENT INDEX
 *
 * The per-edge form yields UINT64_MAX when the snapshot cannot place a
 * neighbour, which happens for a delta addition naming a node the base
 * store does not hold.  The run form cannot yield one: it exists only on
 * the index-only walk, which is exactly the walk with no delta chain, and
 * there every index came out of the CSR's own endpoint array.  So the
 * test is on the fall-back path only, where it is needed, and is not paid
 * per edge on the path that matters.  This is why PageRank's converted
 * gather dropped it, and it is written down once here rather than
 * re-derived at every site.
 *
 * A `double` accumulator's starting value is part of the answer: the run
 * form adds the same terms in the same order, so it is bit-identical only
 * if the accumulator starts where the per-edge form started it.  See
 * pr_gather_slice() in graph_algo_centrality.c. */
#define NEIGHBOR_FOREACH(ctx, ix, ...)                                        \
  do {                                                                        \
    const void *nbf_slice_;                                                   \
    bool nbf_narrow_;                                                         \
    uint32_t nbf_n_, nbf_k_;                                                  \
    bool nbf_by_run_ = false;                                                 \
    uint64_t ix;                                                              \
    while (neighbor_next_run (&(ctx), &nbf_slice_, &nbf_narrow_, &nbf_n_)) {  \
      nbf_by_run_ = true;                                                     \
      for (nbf_k_ = 0; nbf_k_ < nbf_n_; nbf_k_++) {                           \
        (ix) = graph_ix_at (nbf_slice_, nbf_narrow_, nbf_k_);                 \
        __VA_ARGS__                                                           \
      }                                                                       \
    }                                                                         \
    if (!nbf_by_run_) {                                                       \
      while (neighbor_next (&(ctx), &(ix))) {                                 \
        if (UINT64_MAX == (ix)) continue;                                     \
        __VA_ARGS__                                                           \
      }                                                                       \
    }                                                                         \
  } while (0)

/* Id of the neighbour neighbor_next() just returned.  Only the general
 * walk has it to hand; the index-only walk resolves it here, which is why
 * this is a call rather than an output parameter. */
GRAPH_INLINE graph_node_id_t
neighbor_id (const neighbor_ctx_t *ctx)
{
  return (GRAPH_NODE_ID_INVALID != ctx->last_id) ? ctx->last_id : ctx->node_ids[ctx->last_ix];
}

/* Predicate of the edge neighbor_next() just returned.  Valid only on a walk
 * started by neighbor_init_at_pred(); the ordinary walk may take the run form,
 * which yields endpoints without ever reading a predicate. */
GRAPH_INLINE graph_pred_id_t
neighbor_pred (const neighbor_ctx_t *ctx)
{
  return ctx->last_pred;
}

/* As neighbor_init_at(), for a caller that needs each edge's predicate.
 * Clearing `fast` is what forces the per-edge walk: the run form and the
 * index-only path are both gated on it, and neither reads a predicate. */
GRAPH_INLINE void
neighbor_init_at_pred (neighbor_ctx_t *ctx,
    const graph_snapshot_t *snapshot, uint64_t node_index, graph_direction_t direction, const graph_pred_filter_t *pred_filter)
{
  neighbor_init_at (ctx, snapshot, node_index, direction, pred_filter);
  ctx->fast = false;
}

#endif /* GRAPH_NEIGHBOR_H */
