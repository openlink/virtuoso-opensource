/*
 *  graph_algo.h
 *
 *  Graph algorithm API
 *
 *  This header declares all graph algorithms provided by the library.
 *  Algorithms are snapshot-safe and use pre-allocated workspaces to
 *  avoid allocations in hot paths.
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

#ifndef GRAPH_ALGO_H
#define GRAPH_ALGO_H

#include "graph.h"

#ifdef __cplusplus
extern "C"
{
#endif

/* ============================================================================
 * ALGORITHM IDENTIFIERS
 * ============================================================================ */

  typedef enum graph_algo_id
  {
    GRAPH_ALGO_NONE = 0,
    GRAPH_ALGO_BFS = 1,
    GRAPH_ALGO_DFS = 2,
    GRAPH_ALGO_DIJKSTRA = 3,
    GRAPH_ALGO_DEGREE = 4,
    GRAPH_ALGO_PAGERANK = 5,
    GRAPH_ALGO_SCC = 6,
    GRAPH_ALGO_WCC = 7,
    GRAPH_ALGO_BETWEENNESS = 8,
    GRAPH_ALGO_CLOSENESS = 9,
    GRAPH_ALGO_EIGENVECTOR = 10,
    GRAPH_ALGO_HARMONIC = 11,
    GRAPH_ALGO_HITS = 12,
    GRAPH_ALGO_TRIANGLES = 13,
    GRAPH_ALGO_CLUSTERING = 14,
    GRAPH_ALGO_LOUVAIN = 15,
    /* 16 was GRAPH_ALGO_GIRVAN_NEWMAN, whose only implementation set
     * placeholder result fields and returned GRAPH_ERR_NOT_IMPLEMENTED.
     * The id is not reused: it may appear in an old cache dump. */
    GRAPH_ALGO_JACCARD = 17,
    GRAPH_ALGO_KMEANS = 18,
    GRAPH_ALGO_KNN = 19,
    GRAPH_ALGO_LABEL_PROP = 20,
    /* Weighted whole-graph variants.  Separate ids rather than a flag on
     * the unweighted ones, so a cached weighted vector can never be
     * served to an unweighted call or the other way round. */
    GRAPH_ALGO_BETWEENNESS_W = 21,
    GRAPH_ALGO_PAGERANK_W = 22,
    GRAPH_ALGO_EIGENVECTOR_W = 23
  } graph_algo_id_t;

/* ============================================================================
 * BFS (Breadth-First Search)
 * ============================================================================ */

  typedef struct graph_bfs_result
  {
    uint64_t *distances;	/* Distance from source (UINT64_MAX = unreachable) */
    graph_node_id_t *parents;	/* Parent node in BFS tree (0 = no parent) */
    uint64_t node_count;	/* Number of nodes in result arrays */
    uint64_t reached_count;	/* Number of nodes reached from source */
    uint64_t max_distance;	/* Maximum distance found */
  } graph_bfs_result_t;

  size_t graph_algo_bfs_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_bfs (const graph_snapshot_t * snapshot,
      graph_node_id_t source,
      graph_direction_t direction, const graph_pred_filter_t * pred_filter, void *workspace, graph_bfs_result_t * result);

/* ============================================================================
 * DFS (Depth-First Search)
 * ============================================================================ */

  typedef struct graph_dfs_result
  {
    uint64_t *discovery;	/* Discovery time for each node */
    uint64_t *finish;		/* Finish time for each node */
    graph_node_id_t *parents;	/* Parent in DFS tree */
    uint64_t node_count;
    uint64_t reached_count;
    uint64_t time_counter;	/* Final time counter value */
  } graph_dfs_result_t;

  size_t graph_algo_dfs_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_dfs (const graph_snapshot_t * snapshot,
      graph_node_id_t source,
      graph_direction_t direction, const graph_pred_filter_t * pred_filter, void *workspace, graph_dfs_result_t * result);

/* ============================================================================
 * THE INDEX-ONLY NEIGHBOUR WALK
 *
 * With no predicate filter every edge in the store matches, so the only
 * thing the per-edge graph_edge_t load contributes is the neighbour's id
 * -- which the parallel index array already gives as an index, and the
 * node table turns back into an id.  The traversals take that walk by
 * default: one array instead of two, and no predicate test.
 *
 * The switch exists because the answers are identical either way, which
 * means nothing in a result can show which walk ran.  A test needs to be
 * able to run the same question down both, and an operator diagnosing a
 * wrong answer needs to be able to rule one out.
 * ============================================================================ */

  void graph_algo_set_index_walk (bool on);
  bool graph_algo_index_walk (void);

/* Expand a breadth-first level in parallel rather than a vertex at a time.
 * On by default: the answer is identical, bit for bit and at any thread
 * count, because the claim that decides a vertex's parent is made serially
 * in frontier order whatever order the neighbours were read in.  The
 * switch is here for the same reason as the one above -- a test has to be
 * able to run the same question down both paths. */
  void graph_algo_set_parallel_bfs (bool on);
  bool graph_algo_parallel_bfs (void);

/* How PageRank's gather reads a row: 0 iterator-per-edge, 1 whole runs in
 * the same order (bit-identical), 2 whole runs with four accumulators
 * (not bit-identical).  Part of the result-cache key. */
  void graph_algo_set_pagerank_gather (int mode);
  int graph_algo_pagerank_gather (void);
  void graph_algo_set_betweenness_parallel (int mode);
  int graph_algo_betweenness_parallel (void);

/* How many frontier chunks have been expanded that way since startup. */
  uint64_t graph_algo_bfs_parallel_chunks (void);

/* ============================================================================
 * DIJKSTRA (Single-Source Shortest Paths)
 * ============================================================================ */

  typedef struct graph_dijkstra_result
  {
    double *distances;		/* Distance from source (INFINITY = unreachable) */
    graph_node_id_t *parents;	/* Parent in shortest path tree */
    uint64_t node_count;
    uint64_t reached_count;
  } graph_dijkstra_result_t;

  size_t graph_algo_dijkstra_workspace_size (const graph_snapshot_t * snapshot);

/* edge_weights is optional.  When given, the relaxation reads the weight
 * of the edge the neighbour iterator just yielded straight out of the
 * array; weight_func is still consulted for any edge the arrays do not
 * cover, so passing both is not redundant.  Results are identical either
 * way -- the arrays are built by asking weight_func the same questions in
 * advance. */
  graph_error_t graph_algo_dijkstra (const graph_snapshot_t * snapshot,
      graph_node_id_t source,
      graph_direction_t direction,
      const graph_pred_filter_t * pred_filter,
      graph_weight_func_t weight_func,
      void *weight_user_data, const graph_edge_weights_t * edge_weights, void *workspace, graph_dijkstra_result_t * result);

/* ============================================================================
 * DEGREE CENTRALITY
 * ============================================================================ */

  typedef struct graph_degree_result
  {
    uint64_t *out_degrees;	/* Outgoing edge count per node */
    uint64_t *in_degrees;	/* Incoming edge count per node */
    uint64_t *total_degrees;	/* Total degree (in + out) per node */
    uint64_t node_count;
    uint64_t max_out_degree;
    uint64_t max_in_degree;
    double avg_out_degree;
    double avg_in_degree;
  } graph_degree_result_t;

  size_t graph_algo_degree_workspace_size (const graph_snapshot_t * snapshot);

/**
 * Degree of a single node, without the whole-graph pass.
 *
 * With a compacted snapshot and no predicate filter this is a binary search
 * plus two subtractions; otherwise it falls back to counting the node's
 * neighbours.  The scalar degree BIF used to run graph_algo_degree() over
 * the entire graph and then scan the node map linearly to read one number
 * out of the result.
 */
  uint64_t graph_algo_node_degree (const graph_snapshot_t * snapshot,
      graph_node_id_t node, graph_direction_t direction, const graph_pred_filter_t * pred_filter);

  graph_error_t graph_algo_degree (const graph_snapshot_t * snapshot,
      graph_direction_t direction, const graph_pred_filter_t * pred_filter, void *workspace, graph_degree_result_t * result);

/* ============================================================================
 * PAGERANK
 * ============================================================================ */

  typedef struct graph_pagerank_params
  {
    double damping;		/* Damping factor (default: 0.85) */
    double epsilon;		/* Convergence threshold (default: 1e-6) */
    int max_iterations;		/* Maximum iterations (default: 100) */
    /* Treat the graph as directed (default: true).  When false the degree
     * and the gather both run over GRAPH_DIR_BOTH, which is the rank of an
     * undirected graph held one direction per edge.  Leaving it true keeps
     * every existing caller's answer unchanged. */
    bool directed;
  } graph_pagerank_params_t;

  extern const graph_pagerank_params_t GRAPH_PAGERANK_DEFAULT;

  typedef struct graph_pagerank_result
  {
    double *scores;		/* PageRank score per node */
    uint64_t node_count;
    int iterations;		/* Actual iterations performed */
    double residual;		/* Final residual (L1 norm of change) */
    bool converged;		/* True if converged within epsilon */
  } graph_pagerank_result_t;

  size_t graph_algo_pagerank_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_pagerank (const graph_snapshot_t * snapshot,
      const graph_pagerank_params_t * params,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_pagerank_result_t * result);

/* Weighted PageRank using edge weights */
  graph_error_t graph_algo_pagerank_weighted (const graph_snapshot_t * snapshot,
      const graph_pagerank_params_t * params,
      const graph_pred_filter_t * pred_filter,
      graph_weight_func_t weight_func, void *weight_user_data, void *workspace, graph_pagerank_result_t * result);

/* ============================================================================
 * SCC (Strongly Connected Components) - Kosaraju's Algorithm
 * ============================================================================ */

  typedef struct graph_scc_result
  {
    uint64_t *component_ids;	/* Component ID for each node */
    uint64_t node_count;
    uint64_t component_count;	/* Number of SCCs found */
    uint64_t largest_component_size;
  } graph_scc_result_t;

  size_t graph_algo_scc_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_scc (const graph_snapshot_t * snapshot,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_scc_result_t * result);

/* ============================================================================
 * WCC (Weakly Connected Components) - Union-Find
 * ============================================================================ */

  typedef struct graph_wcc_result
  {
    uint64_t *component_ids;	/* Component ID for each node */
    uint64_t node_count;
    uint64_t component_count;
    uint64_t largest_component_size;
  } graph_wcc_result_t;

  size_t graph_algo_wcc_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_wcc (const graph_snapshot_t * snapshot,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_wcc_result_t * result);

/* ============================================================================
 * SHORTEST PATH RECONSTRUCTION
 * ============================================================================ */

  graph_error_t graph_algo_reconstruct_path (const graph_node_id_t * parents,
      uint64_t node_count,
      graph_node_id_t source,
      graph_node_id_t target, graph_node_id_t * path_out, uint64_t path_capacity, uint64_t * path_length_out);

/* ============================================================================
 * WORKSPACE VALIDATION
 * ============================================================================ */

  bool graph_algo_workspace_valid (const void *workspace, graph_algo_id_t algo_id, uint64_t node_count);

  graph_error_t graph_algo_workspace_init (void *workspace, size_t workspace_size, graph_algo_id_t algo_id, uint64_t node_capacity);

#ifdef __cplusplus
}
#endif

#endif				/* GRAPH_ALGO_H */
