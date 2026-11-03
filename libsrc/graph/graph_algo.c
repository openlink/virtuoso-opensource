/*
 *  graph_algo.c
 *
 *  Core graph algorithm implementations
 *
 *  Implements traversal (BFS, DFS, Dijkstra) and connectivity (SCC, WCC)
 *  algorithms. All algorithms are snapshot-safe and allocation-free in hot paths.
 *
 *  Performance characteristics:
 *    - BFS/DFS: O(V + E) time, O(V) space
 *    - Dijkstra: O((V + E) log V) time, O(V) space
 *    - SCC (Kosaraju): O(V + E) time, O(V) space
 *    - WCC (Union-Find): O(V + E × α(V)) time, O(V) space
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
#include "graph_optim.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

/* ============================================================================
 * WORKSPACE LAYOUT UTILITIES
 * ============================================================================ */

#define WS_ALIGN(x) GRAPH_ALIGN_UP(x, GRAPH_CACHE_LINE_SIZE)

static _Thread_local const graph_snapshot_t *algo_snapshot;

/* See the note in graph_algo.h.  Read once per neighbor_init_at(), never per
 * edge, so a plain flag is enough.  It has external linkage because the
 * iterator lives in a header now and every algorithm file has to switch
 * with it -- see the note in graph_neighbor.h. */
bool graph_neighbor_index_walk = true;

void
graph_algo_set_index_walk (bool on)
{
  graph_neighbor_index_walk = on;
}

bool
graph_algo_index_walk (void)
{
  return graph_neighbor_index_walk;
}

/* See the note above graph_algo_bfs() on the level-synchronous expansion. */
static bool g_parallel_bfs = true;

void
graph_algo_set_parallel_bfs (bool on)
{
  g_parallel_bfs = on;
}

bool
graph_algo_parallel_bfs (void)
{
  return g_parallel_bfs;
}

/* Frontier chunks expanded in parallel, since the server started.  The
 * answer is the same either way, so this is the only way a test can tell
 * that the divided path ran rather than being silently declined -- for a
 * small graph, a single-worker server or a snapshot with a delta chain,
 * all of which decline it correctly. */
static uint64_t g_bfs_par_chunks = 0;

uint64_t
graph_algo_bfs_parallel_chunks (void)
{
  return g_bfs_par_chunks;
}

typedef struct ws_bfs_layout
{
  graph_workspace_header_t header;
  uint64_t *visited_bitmap;
  uint64_t *distances;
  graph_node_id_t *parents;
  uint64_t *queue;		/* node *indices* */
  graph_node_id_t *node_map;	/* Maps index to node_id */
  uint64_t *cand;		/* one slot per edge of the chunk in flight */
  uint32_t *cbase;		/* where each frontier vertex's slots start */
  uint64_t bitmap_words;
  uint64_t node_capacity;
} ws_bfs_layout_t;

/* The level expansion writes one slot per edge of the frontier chunk it is
 * working on, so the chunk is sized to fit rather than the buffer sized to
 * fit the chunk.  262,144 slots is 3 MB with the offsets, and at
 * 34,185,747 edges it is about 130 chunks over a whole traversal -- one
 * barrier each, which is nothing against the work between them.
 *
 * Proportional below that, because the buffer is workspace and
 * [Graph] MaxWorkspace defaults to 64 MB: a fixed 3 MB floor would refuse
 * calls on small graphs that a tight budget used to allow. */
#define GRAPH_BFS_CAND_CAP  (1u << 18)
/* Below this many vertices there is nothing to divide up, and the extra
 * pass over the buffer would cost more than the division saves. */
#define GRAPH_BFS_PAR_MIN   1024

static uint64_t
bfs_cand_cap (uint64_t V)
{
  if (V < GRAPH_BFS_PAR_MIN)
    return 0;
  return (V < GRAPH_BFS_CAND_CAP) ? V : GRAPH_BFS_CAND_CAP;
}

/* Degree of one node index in the direction a traversal is walking: the
 * number of slots its expansion can fill. */
static uint64_t
bfs_slot_degree (const graph_base_store_t *base, graph_direction_t direction, uint64_t idx)
{
  uint64_t d = 0;
  if (direction == GRAPH_DIR_OUTGOING || direction == GRAPH_DIR_BOTH)
    d += base->edge_offsets[idx + 1] - base->edge_offsets[idx];
  if ((direction == GRAPH_DIR_INCOMING || direction == GRAPH_DIR_BOTH) && base->has_inverse)
    d += base->inv_offsets[idx + 1] - base->inv_offsets[idx];
  return d;
}

typedef struct ws_dfs_layout
{
  graph_workspace_header_t header;
  uint64_t *visited_bitmap;
  uint64_t *discovery;
  uint64_t *finish;
  graph_node_id_t *parents;
  uint64_t *stack;		/* node *indices* */
  uint32_t *edge_index;		/* Current edge index per node for iterative DFS */
  graph_node_id_t *node_map;
  uint64_t bitmap_words;
  uint64_t node_capacity;
} ws_dfs_layout_t;

typedef struct ws_dijkstra_layout
{
  graph_workspace_header_t header;
  uint64_t *visited_bitmap;
  double *distances;
  graph_node_id_t *parents;
  uint64_t *heap_nodes;		/* node *indices*, not ids */
  double *heap_keys;
  uint64_t *heap_positions;	/* node index -> heap position */
  graph_node_id_t *node_map;
  uint64_t bitmap_words;
  uint64_t node_capacity;
  uint64_t heap_size;
} ws_dijkstra_layout_t;

typedef struct ws_scc_layout
{
  graph_workspace_header_t header;
  uint64_t *visited_bitmap;
  uint64_t *component_ids;
  uint64_t *stack;		/* node *indices* */
  uint64_t *finish_order;	/* node *indices* */
  uint32_t *edge_index;
  graph_node_id_t *node_map;
  uint64_t bitmap_words;
  uint64_t node_capacity;
} ws_scc_layout_t;

typedef struct ws_wcc_layout
{
  graph_workspace_header_t header;
  uint64_t *parent;		/* Union-Find parent */
  uint64_t *rank;		/* Union-Find rank */
  uint64_t *component_ids;
  graph_node_id_t *node_map;
  uint64_t node_capacity;
} ws_wcc_layout_t;

/* ============================================================================
 * BITMAP UTILITIES
 * ============================================================================ */

GRAPH_INLINE void
bitmap_set (uint64_t *bitmap, uint64_t idx)
{
  bitmap[idx >> 6] |= (1ULL << (idx & 63));
}

GRAPH_INLINE bool
bitmap_test (const uint64_t *bitmap, uint64_t idx)
{
  return (bitmap[idx >> 6] & (1ULL << (idx & 63))) != 0;
}

GRAPH_INLINE void
bitmap_clear_all (uint64_t *bitmap, uint64_t words)
{
  memset (bitmap, 0, words * sizeof (uint64_t));
}

/* ============================================================================
 * NODE MAPPING
 * 
 * Build a contiguous index for all nodes in the snapshot.
 * This allows O(1) array access for algorithm data structures.
 * ============================================================================ */

static uint64_t
build_node_map (const graph_snapshot_t *snapshot, graph_node_id_t *node_map, uint64_t capacity)
{
  algo_snapshot = snapshot;
  return graph_snapshot_copy_node_map (snapshot, node_map, capacity);
}

static uint64_t
find_node_index (const graph_node_id_t *node_map, uint64_t count, graph_node_id_t node_id)
{
  (void) node_map;
  (void) count;
  return graph_snapshot_find_node (algo_snapshot, node_id);
}

#include "graph_neighbor.h"


/* ============================================================================
 * BFS IMPLEMENTATION
 * ============================================================================ */

size_t
graph_algo_bfs_workspace_size (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return 0;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    V = 1;

  uint64_t bitmap_words = (V + 63) / 64;

  size_t size = 0;
  size += WS_ALIGN (sizeof (graph_workspace_header_t));
  size += WS_ALIGN (bitmap_words * sizeof (uint64_t));	/* visited */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* distances */
  size += WS_ALIGN (V * sizeof (graph_node_id_t));	/* parents */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* queue */
  size += WS_ALIGN (V * sizeof (graph_node_id_t));	/* node_map */
  {
    uint64_t cap = bfs_cand_cap (V);
    size += WS_ALIGN (cap * sizeof (uint64_t));	/* cand */
    size += WS_ALIGN ((cap + 1) * sizeof (uint32_t));	/* cbase */
  }

  return size;
}

/* One frontier chunk's expansion, run in parallel over frontier positions.
 *
 * Every slot's address is fixed before the slice runs -- cbase[k] is where
 * frontier position k's neighbours go -- so no worker needs an atomic, a
 * lock or a shared cursor, and the buffer reads back in frontier order
 * whatever order the workers filled it in.  That is what makes the answer
 * independent of how the work was divided.
 *
 * visited is read here and written only by the serial pass, so the filter
 * is a hint: a slot survives it if the neighbour looked unvisited at the
 * moment it was read, and the serial pass checks again.  A bit once set is
 * never cleared, so a slot dropped here would have been dropped there
 * too.  That is the whole of the correctness argument. */
typedef struct bfs_expand_ctx
{
  const graph_snapshot_t *snapshot;
  const graph_pred_filter_t *pred_filter;
  graph_direction_t direction;
  const uint64_t *frontier;	/* queue + chunk_lo */
  const uint64_t *visited;
  const uint32_t *cbase;
  uint64_t *cand;
} bfs_expand_ctx_t;

static void
bfs_expand_slice (void *arg, uint64_t start, uint64_t end, uint32_t worker_index)
{
  (void) worker_index;
  bfs_expand_ctx_t *c = (bfs_expand_ctx_t *) arg;
  uint64_t k;

  for (k = start; k < end; k++)
    {
      uint64_t o = c->cbase[k];
      uint64_t stop = c->cbase[k + 1];
      neighbor_ctx_t ctx;
      uint64_t n;

      if (o == stop)
	continue;
      neighbor_init_at (&ctx, c->snapshot, c->frontier[k], c->direction, c->pred_filter);
      /* Not NEIGHBOR_FOREACH, deliberately.  The `o < stop` half of this
       * condition is the deterministic gather's slot bound -- the thing
       * that makes the parallel expansion bit-identical at any worker
       * count -- and a macro body cannot carry it without a `break`,
       * which the run form does not support.  It could be moved into the
       * body as a guard, since the budget above is the row's exact CSR
       * degree and the bound therefore never trips, but "never trips
       * today" is not a reason to move the one line that makes this
       * loop's answer independent of the partition. */
      while (o < stop && neighbor_next (&ctx, &n))
	{
	  c->cand[o++] = (UINT64_MAX != n && !bitmap_test (c->visited, n)) ? n : UINT64_MAX;
	}
      /* A predicate filter can yield fewer than the row holds. */
      while (o < stop)
	c->cand[o++] = UINT64_MAX;
    }
}

graph_error_t
graph_algo_bfs (const graph_snapshot_t *snapshot,
    graph_node_id_t source,
    graph_direction_t direction, const graph_pred_filter_t *pred_filter, void *workspace, graph_bfs_result_t *result)
{
  if (!snapshot || !workspace || !result)
    return GRAPH_ERR_NULL_PTR;
  if (source == GRAPH_NODE_ID_INVALID)
    return GRAPH_ERR_INVALID_ID;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    {
      result->node_count = 0;
      result->reached_count = 0;
      return GRAPH_OK;
    }

  uint64_t bitmap_words = (V + 63) / 64;
  char *ws_ptr = (char *) workspace;

  graph_workspace_header_t *header = (graph_workspace_header_t *) ws_ptr;
  ws_ptr += WS_ALIGN (sizeof (graph_workspace_header_t));

  uint64_t *visited = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (bitmap_words * sizeof (uint64_t));

  uint64_t *distances = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  graph_node_id_t *parents = (graph_node_id_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (graph_node_id_t));

  uint64_t *queue = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  graph_node_id_t *node_map = (graph_node_id_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (graph_node_id_t));

  uint64_t cand_cap = bfs_cand_cap (V);
  uint64_t *cand = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (cand_cap * sizeof (uint64_t));

  uint32_t *cbase = (uint32_t *) ws_ptr;

  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = GRAPH_ALGO_BFS;
  header->node_capacity = V;

  uint64_t node_count = build_node_map (snapshot, node_map, V);

  bitmap_clear_all (visited, bitmap_words);
  for (uint64_t i = 0; i < node_count; i++)
    {
      distances[i] = UINT64_MAX;
      parents[i] = GRAPH_NODE_ID_INVALID;
    }

  uint64_t source_idx = find_node_index (node_map, node_count, source);
  if (source_idx == UINT64_MAX)
    {
      result->node_count = node_count;
      result->reached_count = 0;
      result->distances = distances;
      result->parents = parents;
      result->max_distance = 0;
      return GRAPH_ERR_NOT_FOUND;
    }

  /* The queue holds node indices.  It used to hold ids, and every
   * dequeue then hashed the id back to the index the enqueue already
   * had -- one open-addressing probe into a table of 16 bytes a node per
   * vertex visited.  parents[] is still reported in ids, so the id is
   * read out of node_map once per dequeue instead of once per edge.
   *
   * A single FIFO queue is already level-ordered: every vertex reachable
   * in d steps sits in the queue before every vertex reachable in d + 1,
   * so a level is a contiguous range of it and its vertices all have
   * distance d.  Which is what lets a level be expanded in parallel
   * without any change to the data structure -- see the loop below.
   *
   * The parallel expansion produces the same answer as the serial one,
   * bit for bit and at any thread count, rather than merely an
   * equivalent one.  The serial claim below sweeps the buffer in
   * frontier order, which is the order the one-vertex-at-a-time loop
   * visited edges in, so "the first vertex to reach v becomes its
   * parent" resolves identically.  That mattered: the answer BFS gives
   * for a vertex two paths reach at the same depth is the parent, and
   * parents are pinned. */
  uint64_t queue_tail = 0;
  queue[queue_tail++] = source_idx;
  bitmap_set (visited, source_idx);
  distances[source_idx] = 0;

  uint64_t reached = 1;
  uint64_t max_dist = 0;
  uint64_t level_lo = 0, level_hi = 1, dist = 0;

  const graph_base_store_t *bfs_base = snapshot->graph ? snapshot->graph->base : NULL;
  /* Slots are indexed by CSR position, and the chunk sizing uses the CSR
   * row lengths as the upper bound on what an expansion can yield -- so
   * a snapshot with delta additions, whose edges have no slot and are
   * not counted in a row length, takes the serial path. */
  bool par_ok = g_parallel_bfs && cand_cap > 0 && NULL == snapshot->delta_head &&
      NULL != bfs_base && NULL != bfs_base->edge_offsets;
  graph_parallel_session_t *par = par_ok ? graph_parallel_begin (node_count, GRAPH_PARALLEL_MAX_WORKERS) : NULL;

  while (level_lo < level_hi)
    {
      uint64_t k = level_lo;
      bool use_par = (NULL != par) && (level_hi - level_lo) >= GRAPH_BFS_PAR_MIN;

      while (k < level_hi)
	{
	  uint64_t chunk_lo = k, cnt = 0, sum = 0;

	  if (use_par)
	    {
	      /* Take frontier vertices while their slots still fit. */
	      while (k < level_hi && cnt < cand_cap)
		{
		  uint64_t d = bfs_slot_degree (bfs_base, direction, queue[k]);
		  if (sum + d > cand_cap)
		    break;
		  cbase[cnt++] = (uint32_t) sum;
		  sum += d;
		  k++;
		}
	      cbase[cnt] = (uint32_t) sum;
	    }

	  if (cnt > 0)
	    {
	      bfs_expand_ctx_t ec;
	      uint64_t j;
	      ec.snapshot = snapshot;
	      ec.pred_filter = pred_filter;
	      ec.direction = direction;
	      ec.frontier = queue + chunk_lo;
	      ec.visited = visited;
	      ec.cbase = cbase;
	      ec.cand = cand;
	      graph_parallel_run (par, 0, cnt, bfs_expand_slice, &ec);
	      g_bfs_par_chunks++;

	      for (j = 0; j < cnt; j++)
		{
		  graph_node_id_t current = node_map[queue[chunk_lo + j]];
		  uint64_t o = cbase[j], stop = cbase[j + 1];
		  for (; o < stop; o++)
		    {
		      uint64_t neighbor_idx = cand[o];
		      if (UINT64_MAX == neighbor_idx)
			continue;
		      if (bitmap_test (visited, neighbor_idx))
			continue;
		      bitmap_set (visited, neighbor_idx);
		      distances[neighbor_idx] = dist + 1;
		      parents[neighbor_idx] = current;
		      queue[queue_tail++] = neighbor_idx;
		      reached++;
		      if (dist + 1 > max_dist)
			max_dist = dist + 1;
		    }
		}
	      continue;
	    }

	  /* One vertex, the way it has always been done: the serial
	   * path, and the fallback for a vertex whose own row is larger
	   * than the whole buffer. */
	  {
	    uint64_t current_idx = queue[k++];
	    graph_node_id_t current = node_map[current_idx];
	    neighbor_ctx_t ctx;

	    neighbor_init_at (&ctx, snapshot, current_idx, direction, pred_filter);
	    NEIGHBOR_FOREACH (ctx, neighbor_idx,
		{
		  if (!bitmap_test (visited, neighbor_idx))
		  {
		  bitmap_set (visited, neighbor_idx);
		    distances[neighbor_idx] = dist + 1;
		    parents[neighbor_idx] = current;
		    queue[queue_tail++] = neighbor_idx; reached++; if (dist + 1 > max_dist) max_dist = dist + 1;}
		}
	    );
	  }
	}

      level_lo = level_hi;
      level_hi = queue_tail;
      dist++;
    }
  graph_parallel_end (par);

  result->distances = distances;
  result->parents = parents;
  result->node_count = node_count;
  result->reached_count = reached;
  result->max_distance = max_dist;

  return GRAPH_OK;
}

/* ============================================================================
 * DFS IMPLEMENTATION (Iterative)
 * ============================================================================ */

size_t
graph_algo_dfs_workspace_size (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return 0;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    V = 1;

  uint64_t bitmap_words = (V + 63) / 64;

  size_t size = 0;
  size += WS_ALIGN (sizeof (graph_workspace_header_t));
  size += WS_ALIGN (bitmap_words * sizeof (uint64_t));
  size += WS_ALIGN (V * sizeof (uint64_t));	/* discovery */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* finish */
  size += WS_ALIGN (V * sizeof (graph_node_id_t));	/* parents */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* stack */
  size += WS_ALIGN (V * sizeof (uint32_t));	/* edge_index */
  size += WS_ALIGN (V * sizeof (graph_node_id_t));	/* node_map */

  return size;
}

graph_error_t
graph_algo_dfs (const graph_snapshot_t *snapshot,
    graph_node_id_t source,
    graph_direction_t direction, const graph_pred_filter_t *pred_filter, void *workspace, graph_dfs_result_t *result)
{
  if (!snapshot || !workspace || !result)
    return GRAPH_ERR_NULL_PTR;
  if (source == GRAPH_NODE_ID_INVALID)
    return GRAPH_ERR_INVALID_ID;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    {
      result->node_count = 0;
      result->reached_count = 0;
      return GRAPH_OK;
    }

  uint64_t bitmap_words = (V + 63) / 64;
  char *ws_ptr = (char *) workspace;

  graph_workspace_header_t *header = (graph_workspace_header_t *) ws_ptr;
  ws_ptr += WS_ALIGN (sizeof (graph_workspace_header_t));

  uint64_t *visited = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (bitmap_words * sizeof (uint64_t));

  uint64_t *discovery = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  uint64_t *finish = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  graph_node_id_t *parents = (graph_node_id_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (graph_node_id_t));

  uint64_t *stack = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  uint32_t *edge_index = (uint32_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint32_t));

  graph_node_id_t *node_map = (graph_node_id_t *) ws_ptr;

  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = GRAPH_ALGO_DFS;
  header->node_capacity = V;

  uint64_t node_count = build_node_map (snapshot, node_map, V);

  bitmap_clear_all (visited, bitmap_words);
  for (uint64_t i = 0; i < node_count; i++)
    {
      discovery[i] = UINT64_MAX;
      finish[i] = UINT64_MAX;
      parents[i] = GRAPH_NODE_ID_INVALID;
      edge_index[i] = 0;
    }

  uint64_t source_idx = find_node_index (node_map, node_count, source);
  if (source_idx == UINT64_MAX)
    {
      result->node_count = node_count;
      result->reached_count = 0;
      result->discovery = discovery;
      result->finish = finish;
      result->parents = parents;
      result->time_counter = 0;
      return GRAPH_ERR_NOT_FOUND;
    }

  uint64_t time_counter = 0;
  uint64_t stack_top = 0;
  uint64_t reached = 0;

  stack[stack_top++] = source_idx;

  while (stack_top > 0)
    {
      uint64_t current_idx = stack[stack_top - 1];

      if (!bitmap_test (visited, current_idx))
	{
	  bitmap_set (visited, current_idx);
	  discovery[current_idx] = time_counter++;
	  reached++;
	}

      bool found_unvisited = false;
      neighbor_ctx_t ctx;
      neighbor_init_at (&ctx, snapshot, current_idx, direction, pred_filter);

      /* Resume where this vertex left off.  A vertex of degree d is
       * returned to up to d times, and re-counting the edges already
       * dealt with on each return is O(d*d) -- on a power-law graph one
       * high-degree vertex is then the whole running time.  The
       * index-only walk can jump straight to the position; the general
       * walk still counts, because a filtered sequence has no position
       * to jump to. */
      uint32_t skip = edge_index[current_idx];
      uint32_t edge_count = neighbor_skip (&ctx, skip) ? skip : 0;
      uint64_t neighbor_idx;
      while (neighbor_next (&ctx, &neighbor_idx))
	{
	  if (edge_count < skip)
	    {
	      edge_count++;
	      continue;
	    }
	  edge_index[current_idx] = edge_count + 1;

	  if (neighbor_idx == UINT64_MAX)
	    {
	      edge_count++;
	      continue;
	    }

	  if (!bitmap_test (visited, neighbor_idx))
	    {
	      parents[neighbor_idx] = node_map[current_idx];
	      stack[stack_top++] = neighbor_idx;
	      found_unvisited = true;
	      break;
	    }
	  edge_count++;
	}

      if (!found_unvisited)
	{
	  finish[current_idx] = time_counter++;
	  stack_top--;
	}
    }

  result->discovery = discovery;
  result->finish = finish;
  result->parents = parents;
  result->node_count = node_count;
  result->reached_count = reached;
  result->time_counter = time_counter;

  return GRAPH_OK;
}

/* ============================================================================
 * DIJKSTRA IMPLEMENTATION (Binary Heap)
 * ============================================================================ */

size_t
graph_algo_dijkstra_workspace_size (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return 0;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    V = 1;

  uint64_t bitmap_words = (V + 63) / 64;

  size_t size = 0;
  size += WS_ALIGN (sizeof (graph_workspace_header_t));
  size += WS_ALIGN (bitmap_words * sizeof (uint64_t));
  size += WS_ALIGN (V * sizeof (double));	/* distances */
  size += WS_ALIGN (V * sizeof (graph_node_id_t));	/* parents */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* heap_nodes */
  size += WS_ALIGN (V * sizeof (double));	/* heap_keys */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* heap_positions */
  size += WS_ALIGN (V * sizeof (graph_node_id_t));	/* node_map */

  return size;
}

/* The heap holds node *indices*.  It used to hold node ids, which meant
 * every swap had to hash both of them back to an index to keep
 * positions[] current -- two open-addressing probes into a table that is
 * 16 bytes a node, so 16 MB at 633,432 nodes and nowhere near L2, once per
 * level of every sift.  An index is what positions[] is keyed on, so
 * storing it makes the update a direct write and the probes disappear.
 *
 * Nothing about the heap's order changes: the comparisons read keys[] and
 * never the stored value, so the sequence of swaps for a given sequence of
 * pushes and decrease-keys is exactly what it was.  That matters because
 * Dijkstra's pop order decides which parent a vertex gets when two paths
 * tie, and those parent arrays are pinned. */
static void
heap_swap (uint64_t *nodes, double *keys, uint64_t *positions, uint64_t i, uint64_t j)
{
  uint64_t tmp_node = nodes[i];
  double tmp_key = keys[i];

  nodes[i] = nodes[j];
  keys[i] = keys[j];
  nodes[j] = tmp_node;
  keys[j] = tmp_key;

  positions[nodes[i]] = i;
  positions[nodes[j]] = j;
}

static void
heap_bubble_up (uint64_t *nodes, double *keys, uint64_t *positions, uint64_t idx)
{
  while (idx > 0)
    {
      uint64_t parent = (idx - 1) / 2;
      if (keys[idx] < keys[parent])
	{
	  heap_swap (nodes, keys, positions, idx, parent);
	  idx = parent;
	}
      else
	{
	  break;
	}
    }
}

static void
heap_bubble_down (uint64_t *nodes, double *keys, uint64_t *positions, uint64_t idx, uint64_t heap_size)
{
  while (true)
    {
      uint64_t smallest = idx;
      uint64_t left = 2 * idx + 1;
      uint64_t right = 2 * idx + 2;

      if (left < heap_size && keys[left] < keys[smallest])
	{
	  smallest = left;
	}
      if (right < heap_size && keys[right] < keys[smallest])
	{
	  smallest = right;
	}

      if (smallest != idx)
	{
	  heap_swap (nodes, keys, positions, idx, smallest);
	  idx = smallest;
	}
      else
	{
	  break;
	}
    }
}

graph_error_t
graph_algo_dijkstra (const graph_snapshot_t *snapshot,
    graph_node_id_t source,
    graph_direction_t direction,
    const graph_pred_filter_t *pred_filter,
    graph_weight_func_t weight_func,
    void *weight_user_data, const graph_edge_weights_t *edge_weights, void *workspace, graph_dijkstra_result_t *result)
{
  if (!snapshot || !workspace || !result)
    return GRAPH_ERR_NULL_PTR;
  if (source == GRAPH_NODE_ID_INVALID)
    return GRAPH_ERR_INVALID_ID;

  if (!weight_func)
    weight_func = GRAPH_WEIGHT_UNIFORM;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    {
      result->node_count = 0;
      result->reached_count = 0;
      return GRAPH_OK;
    }

  uint64_t bitmap_words = (V + 63) / 64;
  char *ws_ptr = (char *) workspace;

  graph_workspace_header_t *header = (graph_workspace_header_t *) ws_ptr;
  ws_ptr += WS_ALIGN (sizeof (graph_workspace_header_t));

  uint64_t *visited = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (bitmap_words * sizeof (uint64_t));

  double *distances = (double *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (double));

  graph_node_id_t *parents = (graph_node_id_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (graph_node_id_t));

  uint64_t *heap_nodes = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  double *heap_keys = (double *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (double));

  uint64_t *heap_positions = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  graph_node_id_t *node_map = (graph_node_id_t *) ws_ptr;

  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = GRAPH_ALGO_DIJKSTRA;
  header->node_capacity = V;

  uint64_t node_count = build_node_map (snapshot, node_map, V);

  bitmap_clear_all (visited, bitmap_words);
  for (uint64_t i = 0; i < node_count; i++)
    {
      distances[i] = INFINITY;
      parents[i] = GRAPH_NODE_ID_INVALID;
      heap_positions[i] = UINT64_MAX;
    }

  uint64_t source_idx = find_node_index (node_map, node_count, source);
  if (source_idx == UINT64_MAX)
    {
      result->distances = distances;
      result->parents = parents;
      result->node_count = node_count;
      result->reached_count = 0;
      return GRAPH_ERR_NOT_FOUND;
    }

  distances[source_idx] = 0.0;

  uint64_t heap_size = 1;
  heap_nodes[0] = source_idx;
  heap_keys[0] = 0.0;
  heap_positions[source_idx] = 0;

  uint64_t reached = 0;

  while (heap_size > 0)
    {
      uint64_t current_idx = heap_nodes[0];

      heap_size--;
      if (heap_size > 0)
	{
	  heap_nodes[0] = heap_nodes[heap_size];
	  heap_keys[0] = heap_keys[heap_size];
	  heap_positions[heap_nodes[0]] = 0;
	  heap_bubble_down (heap_nodes, heap_keys, heap_positions, 0, heap_size);
	}

      if (bitmap_test (visited, current_idx))
	continue;
      bitmap_set (visited, current_idx);
      reached++;

      /* The id is still needed for parents[], which is reported in ids,
       * and for the weight-function fallback.  One indexed load per
       * popped vertex, against a hash probe per heap level before. */
      graph_node_id_t current = node_map[current_idx];
      double current_dist = distances[current_idx];

      neighbor_ctx_t ctx;
      neighbor_init_weighted_at (&ctx, snapshot, current_idx, direction, pred_filter, edge_weights);

      uint64_t neighbor_idx;
      while (neighbor_next (&ctx, &neighbor_idx))
	{
	  if (neighbor_idx == UINT64_MAX)
	    continue;
	  if (bitmap_test (visited, neighbor_idx))
	    continue;

	  /* One indexed load when the weights were resolved into slot
	   * order, and the general lookup otherwise.  The array was
	   * built by asking weight_func this same question, so the two
	   * branches return the same double. */
	  double edge_weight = ctx.last_weight_valid
	      ? ctx.last_weight : weight_func (current, 0, neighbor_id (&ctx), weight_user_data);
	  if (edge_weight < 0)
	    {
	      return GRAPH_ERR_NEGATIVE_CYCLE;
	    }

	  double new_dist = current_dist + edge_weight;
	  if (new_dist < distances[neighbor_idx])
	    {
	      distances[neighbor_idx] = new_dist;
	      parents[neighbor_idx] = current;

	      if (heap_positions[neighbor_idx] == UINT64_MAX)
		{
		  heap_nodes[heap_size] = neighbor_idx;
		  heap_keys[heap_size] = new_dist;
		  heap_positions[neighbor_idx] = heap_size;
		  heap_bubble_up (heap_nodes, heap_keys, heap_positions, heap_size);
		  heap_size++;
		}
	      else
		{
		  uint64_t pos = heap_positions[neighbor_idx];
		  heap_keys[pos] = new_dist;
		  heap_bubble_up (heap_nodes, heap_keys, heap_positions, pos);
		}
	    }
	}
    }

  result->distances = distances;
  result->parents = parents;
  result->node_count = node_count;
  result->reached_count = reached;

  return GRAPH_OK;
}

/* ============================================================================
 * WCC IMPLEMENTATION (Union-Find)
 * ============================================================================ */

size_t
graph_algo_wcc_workspace_size (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return 0;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    V = 1;

  size_t size = 0;
  size += WS_ALIGN (sizeof (graph_workspace_header_t));
  size += WS_ALIGN (V * sizeof (uint64_t));	/* parent */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* rank */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* component_ids */
  size += WS_ALIGN (V * sizeof (graph_node_id_t));	/* node_map */

  return size;
}

/* Find with full path compression, iteratively.
 *
 * This was recursive, and the recursion depth is the height of the
 * union-find tree.  Union by rank keeps that height logarithmic *on
 * average*, which is not the same as bounded: the height is only
 * logarithmic once enough finds have compressed the paths, and the shape
 * before that depends on the order the edges arrive in.  At 633,432
 * nodes a run of unions in the wrong order is a deep chain and a deep
 * chain is a stack overflow, in a function with no way to report one.
 *
 * The two passes leave parent[] in exactly the state the recursion did:
 * the first finds the root, the second points every node on the path
 * straight at it, which is what the recursive form did on the way back
 * out. */
static uint64_t
uf_find (uint64_t *parent, uint64_t x)
{
  uint64_t root = x;
  while (parent[root] != root)
    root = parent[root];
  while (parent[x] != root)
    {
      uint64_t next = parent[x];
      parent[x] = root;
      x = next;
    }
  return root;
}

static void
uf_union (uint64_t *parent, uint64_t *rank, uint64_t x, uint64_t y)
{
  uint64_t rx = uf_find (parent, x);
  uint64_t ry = uf_find (parent, y);

  if (rx == ry)
    return;

  if (rank[rx] < rank[ry])
    {
      parent[rx] = ry;
    }
  else if (rank[rx] > rank[ry])
    {
      parent[ry] = rx;
    }
  else
    {
      parent[ry] = rx;
      rank[rx]++;
    }
}

graph_error_t
graph_algo_wcc (const graph_snapshot_t *snapshot,
    const graph_pred_filter_t *pred_filter, void *workspace, graph_wcc_result_t *result)
{
  if (!snapshot || !workspace || !result)
    return GRAPH_ERR_NULL_PTR;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    {
      result->node_count = 0;
      result->component_count = 0;
      return GRAPH_OK;
    }

  char *ws_ptr = (char *) workspace;

  graph_workspace_header_t *header = (graph_workspace_header_t *) ws_ptr;
  ws_ptr += WS_ALIGN (sizeof (graph_workspace_header_t));

  uint64_t *parent = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  uint64_t *rank = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  uint64_t *component_ids = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  graph_node_id_t *node_map = (graph_node_id_t *) ws_ptr;

  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = GRAPH_ALGO_WCC;
  header->node_capacity = V;

  uint64_t node_count = build_node_map (snapshot, node_map, V);

  for (uint64_t i = 0; i < node_count; i++)
    {
      parent[i] = i;
      rank[i] = 0;
    }

  for (uint64_t i = 0; i < node_count; i++)
    {
      neighbor_ctx_t ctx;
      /* WCC never looks at a neighbour's id, only at its index, so this
       * loop touches no node id at all now: the row is addressed by
       * index and the endpoint comes back as one. */
      neighbor_init_at (&ctx, snapshot, i, GRAPH_DIR_OUTGOING, pred_filter);

      /* Component ids are pinned values and union-find's result depends
       * on the order the unions are applied in.  A run yields exactly
       * the sequence the per-edge walk did, so the order is the same and
       * nothing else about this loop changes. */
      NEIGHBOR_FOREACH (ctx, neighbor_idx,
	  {
	  uf_union (parent, rank, i, neighbor_idx);}
      );
    }

  uint64_t component_count = 0;
  uint64_t *root_to_component = rank;
  memset (root_to_component, 0xFF, node_count * sizeof (uint64_t));

  uint64_t largest_size = 0;

  for (uint64_t i = 0; i < node_count; i++)
    {
      uint64_t root = uf_find (parent, i);
      if (root_to_component[root] == UINT64_MAX)
	{
	  root_to_component[root] = component_count++;
	}
      component_ids[i] = root_to_component[root];
    }

  /* Calculate largest component size */
  memset (rank, 0, node_count * sizeof (uint64_t));	/* Reuse as size counter */
  for (uint64_t i = 0; i < node_count; i++)
    {
      rank[component_ids[i]]++;
      if (rank[component_ids[i]] > largest_size)
	{
	  largest_size = rank[component_ids[i]];
	}
    }

  result->component_ids = component_ids;
  result->node_count = node_count;
  result->component_count = component_count;
  result->largest_component_size = largest_size;

  return GRAPH_OK;
}

/* ============================================================================
 * SCC IMPLEMENTATION (Kosaraju's Algorithm)
 * ============================================================================ */

size_t
graph_algo_scc_workspace_size (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return 0;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    V = 1;

  uint64_t bitmap_words = (V + 63) / 64;

  size_t size = 0;
  size += WS_ALIGN (sizeof (graph_workspace_header_t));
  size += WS_ALIGN (bitmap_words * sizeof (uint64_t));
  size += WS_ALIGN (V * sizeof (uint64_t));	/* component_ids */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* stack */
  size += WS_ALIGN (V * sizeof (uint64_t));	/* finish_order */
  size += WS_ALIGN (V * sizeof (uint32_t));	/* edge_index */
  size += WS_ALIGN (V * sizeof (graph_node_id_t));	/* node_map */

  return size;
}

graph_error_t
graph_algo_scc (const graph_snapshot_t *snapshot,
    const graph_pred_filter_t *pred_filter, void *workspace, graph_scc_result_t *result)
{
  if (!snapshot || !workspace || !result)
    return GRAPH_ERR_NULL_PTR;

  uint64_t V = snapshot->node_count;
  if (V == 0)
    {
      result->node_count = 0;
      result->component_count = 0;
      return GRAPH_OK;
    }

  uint64_t bitmap_words = (V + 63) / 64;
  char *ws_ptr = (char *) workspace;

  graph_workspace_header_t *header = (graph_workspace_header_t *) ws_ptr;
  ws_ptr += WS_ALIGN (sizeof (graph_workspace_header_t));

  uint64_t *visited = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (bitmap_words * sizeof (uint64_t));

  uint64_t *component_ids = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  uint64_t *stack = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  uint64_t *finish_order = (uint64_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint64_t));

  uint32_t *edge_index = (uint32_t *) ws_ptr;
  ws_ptr += WS_ALIGN (V * sizeof (uint32_t));

  graph_node_id_t *node_map = (graph_node_id_t *) ws_ptr;

  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = GRAPH_ALGO_SCC;
  header->node_capacity = V;

  uint64_t node_count = build_node_map (snapshot, node_map, V);

  bitmap_clear_all (visited, bitmap_words);
  for (uint64_t i = 0; i < node_count; i++)
    {
      component_ids[i] = UINT64_MAX;
      edge_index[i] = 0;
    }

  uint64_t finish_idx = 0;

  for (uint64_t start = 0; start < node_count; start++)
    {
      if (bitmap_test (visited, start))
	continue;

      uint64_t stack_top = 0;
      stack[stack_top++] = start;

      while (stack_top > 0)
	{
	  uint64_t current_idx = stack[stack_top - 1];

	  if (!bitmap_test (visited, current_idx))
	    {
	      bitmap_set (visited, current_idx);
	    }

	  bool found = false;
	  neighbor_ctx_t ctx;
	  neighbor_init_at (&ctx, snapshot, current_idx, GRAPH_DIR_OUTGOING, pred_filter);

	  /* Same resume as in DFS above, and for the same reason. */
	  uint32_t skip = edge_index[current_idx];
	  uint32_t edge_count = neighbor_skip (&ctx, skip) ? skip : 0;
	  uint64_t neighbor_idx;
	  while (neighbor_next (&ctx, &neighbor_idx))
	    {
	      if (edge_count < skip)
		{
		  edge_count++;
		  continue;
		}
	      edge_index[current_idx] = edge_count + 1;

	      if (neighbor_idx == UINT64_MAX)
		{
		  edge_count++;
		  continue;
		}

	      if (!bitmap_test (visited, neighbor_idx))
		{
		  stack[stack_top++] = neighbor_idx;
		  found = true;
		  break;
		}
	      edge_count++;
	    }

	  if (!found)
	    {
	      finish_order[finish_idx++] = current_idx;
	      stack_top--;
	    }
	}
    }

  bitmap_clear_all (visited, bitmap_words);
  for (uint64_t i = 0; i < node_count; i++)
    {
      edge_index[i] = 0;
    }

  uint64_t component_count = 0;
  uint64_t largest_size = 0;

  for (int64_t fi = (int64_t) finish_idx - 1; fi >= 0; fi--)
    {
      uint64_t start_idx = finish_order[fi];

      if (bitmap_test (visited, start_idx))
	continue;

      uint64_t component_size = 0;
      uint64_t stack_top = 0;
      stack[stack_top++] = start_idx;

      while (stack_top > 0)
	{
	  uint64_t current_idx = stack[stack_top - 1];

	  if (!bitmap_test (visited, current_idx))
	    {
	      bitmap_set (visited, current_idx);
	      component_ids[current_idx] = component_count;
	      component_size++;
	    }

	  bool found = false;
	  neighbor_ctx_t ctx;
	  neighbor_init_at (&ctx, snapshot, current_idx, GRAPH_DIR_INCOMING, pred_filter);

	  uint32_t skip = edge_index[current_idx];
	  uint32_t edge_count = neighbor_skip (&ctx, skip) ? skip : 0;
	  uint64_t neighbor_idx;
	  while (neighbor_next (&ctx, &neighbor_idx))
	    {
	      if (edge_count < skip)
		{
		  edge_count++;
		  continue;
		}
	      edge_index[current_idx] = edge_count + 1;

	      if (neighbor_idx == UINT64_MAX)
		{
		  edge_count++;
		  continue;
		}

	      if (!bitmap_test (visited, neighbor_idx))
		{
		  stack[stack_top++] = neighbor_idx;
		  found = true;
		  break;
		}
	      edge_count++;
	    }

	  if (!found)
	    {
	      stack_top--;
	    }
	}

      if (component_size > largest_size)
	{
	  largest_size = component_size;
	}
      component_count++;
    }

  result->component_ids = component_ids;
  result->node_count = node_count;
  result->component_count = component_count;
  result->largest_component_size = largest_size;

  return GRAPH_OK;
}

/* ============================================================================
 * PATH RECONSTRUCTION
 * ============================================================================ */

graph_error_t
graph_algo_reconstruct_path (const graph_node_id_t *parents,
    uint64_t node_count,
    graph_node_id_t source, graph_node_id_t target, graph_node_id_t *path_out, uint64_t path_capacity, uint64_t *path_length_out)
{
  if (!parents || !path_out || !path_length_out)
    return GRAPH_ERR_NULL_PTR;

  graph_node_id_t current = target;
  uint64_t length = 0;

  while (current != GRAPH_NODE_ID_INVALID && current != source)
    {
      if (length >= path_capacity)
	return GRAPH_ERR_CAPACITY_EXCEEDED;
      path_out[length++] = current;

      bool found = false;
      for (uint64_t i = 0; i < node_count; i++)
	{
	  if (i == length - 1)
	    {
	      current = parents[i];
	      found = true;
	      break;
	    }
	}
      if (!found)
	break;

      if (length > node_count)
	return GRAPH_ERR_CORRUPTED;
    }

  if (current != source)
    {
      *path_length_out = 0;
      return GRAPH_ERR_NO_PATH;
    }

  path_out[length++] = source;

  for (uint64_t i = 0; i < length / 2; i++)
    {
      graph_node_id_t tmp = path_out[i];
      path_out[i] = path_out[length - 1 - i];
      path_out[length - 1 - i] = tmp;
    }

  *path_length_out = length;
  return GRAPH_OK;
}

/* ============================================================================
 * WORKSPACE VALIDATION
 * ============================================================================ */

bool
graph_algo_workspace_valid (const void *workspace, graph_algo_id_t algo_id, uint64_t node_count)
{
  if (!workspace)
    return false;

  const graph_workspace_header_t *header = (const graph_workspace_header_t *) workspace;

  if (header->magic != GRAPH_WORKSPACE_MAGIC)
    return false;
  if (header->algorithm_id != algo_id)
    return false;
  if (header->node_capacity < node_count)
    return false;

  return true;
}

graph_error_t
graph_algo_workspace_init (void *workspace, size_t workspace_size, graph_algo_id_t algo_id, uint64_t node_capacity)
{
  if (!workspace)
    return GRAPH_ERR_NULL_PTR;
  if (workspace_size < sizeof (graph_workspace_header_t))
    return GRAPH_ERR_WORKSPACE_TOO_SMALL;

  graph_workspace_header_t *header = (graph_workspace_header_t *) workspace;
  header->magic = GRAPH_WORKSPACE_MAGIC;
  header->algorithm_id = algo_id;
  header->node_capacity = node_capacity;
  header->triple_capacity = 0;

  return GRAPH_OK;
}
