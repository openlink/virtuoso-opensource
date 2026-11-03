/*
 *  graph_algo_advanced.h
 *
 *  Advanced graph algorithm API
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

#ifndef GRAPH_ALGO_ADVANCED_H
#define GRAPH_ALGO_ADVANCED_H

#include "graph.h"

#ifdef __cplusplus
extern "C"
{
#endif

/* ============================================================================
 * BETWEENNESS CENTRALITY
 * ============================================================================ */

  typedef struct graph_betweenness_params
  {
    bool normalized;
    bool endpoints;
    bool directed;		/* true=directed (default), false=undirected */
    uint64_t sample_size;
    uint64_t seed;
  } graph_betweenness_params_t;

  extern const graph_betweenness_params_t GRAPH_BETWEENNESS_DEFAULT;

  typedef struct graph_betweenness_result
  {
    double *scores;
    uint64_t node_count;
    double max_score;
    double avg_score;
  } graph_betweenness_result_t;

  size_t graph_algo_betweenness_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_betweenness (const graph_snapshot_t * snapshot,
      const graph_betweenness_params_t * params,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_betweenness_result_t * result);

/* Weighted betweenness centrality using Dijkstra instead of BFS */
  graph_error_t graph_algo_betweenness_weighted (const graph_snapshot_t * snapshot,
      const graph_betweenness_params_t * params,
      const graph_pred_filter_t * pred_filter,
      graph_weight_func_t weight_func, void *weight_user_data, void *workspace, graph_betweenness_result_t * result);

/* ============================================================================
 * CLOSENESS CENTRALITY
 * ============================================================================ */

  typedef struct graph_closeness_params
  {
    bool normalized;
    bool harmonic;
    /* Which way the measure looks.  Closeness and harmonic could only ever
     * be read outgoing; OUTGOING stays the default so no shipped answer
     * moves.  This is the traversal encoding that bfs, dfs and
     * shortest_path use -- not degree_centrality's, where 0 is BOTH. */
    graph_direction_t direction;
  } graph_closeness_params_t;

  extern const graph_closeness_params_t GRAPH_CLOSENESS_DEFAULT;

  typedef struct graph_closeness_result
  {
    double *scores;
    uint64_t node_count;
    double max_score;
    double avg_score;
  } graph_closeness_result_t;

  size_t graph_algo_closeness_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_closeness (const graph_snapshot_t * snapshot,
      const graph_closeness_params_t * params,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_closeness_result_t * result);

/* Single-source closeness: compute only target_node's score with one BFS
 * (O(V+E)) instead of the full all-sources pass (O(V*(V+E))).  Uses the
 * graph_algo_closeness workspace layout.  The score is bit-identical to
 * the same node's entry in a full graph_algo_closeness() run. */
  graph_error_t graph_algo_closeness_single (const graph_snapshot_t * snapshot,
      const graph_closeness_params_t * params,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_node_id_t target_node, double *out_score);

/* Weighted closeness centrality using Dijkstra distances */
  graph_error_t graph_algo_closeness_weighted (const graph_snapshot_t * snapshot,
      const graph_closeness_params_t * params,
      const graph_pred_filter_t * pred_filter,
      graph_weight_func_t weight_func, void *weight_user_data, void *workspace, graph_closeness_result_t * result);

/* ============================================================================
 * EIGENVECTOR CENTRALITY
 * ============================================================================ */

  typedef struct graph_eigenvector_params
  {
    double epsilon;
    int max_iterations;
    /* No `normalized`.  Both of these are power iteration, which divides
     * the vector by its L2 norm on every pass -- and the convergence test
     * compares successive *normalized* iterates, so the normalisation is
     * what makes the loop terminate rather than a presentation choice.
     * Nor is there a raw quantity to expose: an eigenvector is defined
     * only up to scale, so an unnormalised one says no more than which
     * iteration you stopped on.  Contrast graph_betweenness_params_t and
     * graph_closeness_params_t, which do carry the flag, because raw
     * betweenness is a count of shortest paths and raw closeness is
     * 1/sum(d) -- both meaningful before any scaling. */
  } graph_eigenvector_params_t;

  extern const graph_eigenvector_params_t GRAPH_EIGENVECTOR_DEFAULT;

  typedef struct graph_eigenvector_result
  {
    double *scores;
    uint64_t node_count;
    int iterations;
    double residual;
    bool converged;
  } graph_eigenvector_result_t;

  size_t graph_algo_eigenvector_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_eigenvector (const graph_snapshot_t * snapshot,
      const graph_eigenvector_params_t * params,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_eigenvector_result_t * result);

/* Weighted eigenvector centrality using edge weights */
  graph_error_t graph_algo_eigenvector_weighted (const graph_snapshot_t * snapshot,
      const graph_eigenvector_params_t * params,
      const graph_pred_filter_t * pred_filter,
      graph_weight_func_t weight_func, void *weight_user_data, void *workspace, graph_eigenvector_result_t * result);

/* ============================================================================
 * HARMONIC CENTRALITY
 * ============================================================================ */

  typedef struct graph_harmonic_result
  {
    double *scores;
    uint64_t node_count;
    double max_score;
    double avg_score;
  } graph_harmonic_result_t;

  size_t graph_algo_harmonic_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_harmonic (const graph_snapshot_t * snapshot,
      const graph_closeness_params_t * params,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_harmonic_result_t * result);

/* ============================================================================
 * HITS (Hubs and Authorities)
 * ============================================================================ */

  typedef struct graph_hits_params
  {
    double epsilon;
    int max_iterations;
    /* No `normalized`.  Both of these are power iteration, which divides
     * the vector by its L2 norm on every pass -- and the convergence test
     * compares successive *normalized* iterates, so the normalisation is
     * what makes the loop terminate rather than a presentation choice.
     * Nor is there a raw quantity to expose: an eigenvector is defined
     * only up to scale, so an unnormalised one says no more than which
     * iteration you stopped on.  Contrast graph_betweenness_params_t and
     * graph_closeness_params_t, which do carry the flag, because raw
     * betweenness is a count of shortest paths and raw closeness is
     * 1/sum(d) -- both meaningful before any scaling. */
  } graph_hits_params_t;

  extern const graph_hits_params_t GRAPH_HITS_DEFAULT;

  typedef struct graph_hits_result
  {
    double *hub_scores;
    double *authority_scores;
    uint64_t node_count;
    int iterations;
    bool converged;
  } graph_hits_result_t;

  size_t graph_algo_hits_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_hits (const graph_snapshot_t * snapshot,
      const graph_hits_params_t * params, const graph_pred_filter_t * pred_filter, void *workspace, graph_hits_result_t * result);

/* ============================================================================
 * TRIANGLE COUNTING
 * ============================================================================ */

  typedef struct graph_triangles_result
  {
    uint64_t *triangle_counts;
    uint64_t node_count;
    uint64_t total_triangles;
  } graph_triangles_result_t;

  size_t graph_algo_triangles_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_triangles (const graph_snapshot_t * snapshot,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_triangles_result_t * result);

/* ============================================================================
 * LCC - LOCAL CLUSTERING COEFFICIENT
 *
 * lcc(v) = triangles(v) / (d(v) * (d(v) - 1) / 2), and 0 when d(v) < 2.
 * d(v) is the undirected degree, counting a directed edge once in each
 * direction, matching triangle counting and GRAPH_DEGREE_CENTRALITY.
 * ============================================================================ */

/* On a directed graph the two conventions above are not the usual ones.
 * With `directed` set, the neighbourhood is the DISTINCT set over both
 * directions, and the numerator counts ORDERED pairs of neighbours joined
 * by a directed edge:
 *
 *   lcc(v) = |{(u,w) in N(v) x N(v) : u->w in E}| / (d(v) * (d(v) - 1))
 *
 * On an undirected graph held one direction per edge the two coincide,
 * which is why the default is the cheaper triangle form. */
  typedef struct graph_clustering_params
  {
    bool directed;		/* default: false, today's behaviour */
  } graph_clustering_params_t;

  extern const graph_clustering_params_t GRAPH_CLUSTERING_DEFAULT;

  typedef struct graph_clustering_result
  {
    double *coefficients;
    uint64_t node_count;
    /* Mean over ALL nodes, with the d < 2 nodes counted as the zeroes
     * they are - the mean local clustering coefficient in its usual
     * form, and recomputable from coefficients[] alone. */
    double avg_coefficient;
  } graph_clustering_result_t;

  size_t graph_algo_clustering_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_clustering (const graph_snapshot_t * snapshot,
      const graph_clustering_params_t * params,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_clustering_result_t * result);

/* ============================================================================
 * LOUVAIN COMMUNITY DETECTION
 * ============================================================================ */

  typedef struct graph_louvain_params
  {
    double resolution;
    double epsilon;
    int max_iterations;
    int max_levels;
  } graph_louvain_params_t;

  extern const graph_louvain_params_t GRAPH_LOUVAIN_DEFAULT;

  typedef struct graph_louvain_result
  {
    uint64_t *community_ids;
    uint64_t node_count;
    uint64_t community_count;
    double modularity;
    int levels;
  } graph_louvain_result_t;

  size_t graph_algo_louvain_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_louvain (const graph_snapshot_t * snapshot,
      const graph_louvain_params_t * params,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_louvain_result_t * result);

/* ============================================================================
 * CDLP - COMMUNITY DETECTION BY LABEL PROPAGATION
 *
 * The deterministic variant: updates are synchronous (every node reads
 * the previous iteration's labels, never a half-updated array), the
 * iteration count is fixed, and ties are broken by the SMALLEST label
 * among those with the highest frequency.  A directed edge counts once in each direction, so the
 * neighbour set is GRAPH_DIR_BOTH and an edge present in both directions
 * contributes twice.
 *
 * This is not GRAPH_ALGO_LOUVAIN.  Louvain optimises modularity and
 * produces a different partition; CDLP is the one to reach for when the
 * answer has to line up with another engine's label propagation.
 * ============================================================================ */

/* What the label of a community is reported as.
 *
 * DENSE renumbers to [0, community_count) and is what every existing
 * caller sees.  NODE_ID reports the community's representative vertex -
 * the winning node's own id - which is the form a comparison against
 * another implementation's output needs, since those name a community
 * after a real vertex rather than after a counter. */
  typedef enum graph_labelprop_label_form
  {
    GRAPH_LABELPROP_LABELS_DENSE = 0,
    GRAPH_LABELPROP_LABELS_NODE_ID = 1
  } graph_labelprop_label_form_t;

  typedef struct graph_labelprop_params
  {
    int max_iterations;		/* Fixed iteration count (default: 10) */
    graph_labelprop_label_form_t label_form;	/* default: DENSE */
  } graph_labelprop_params_t;

  extern const graph_labelprop_params_t GRAPH_LABELPROP_DEFAULT;

  typedef struct graph_labelprop_result
  {
    uint64_t *labels;		/* Dense community label per node */
    uint64_t node_count;
    uint64_t community_count;
    int iterations;		/* Iterations actually run (<= max_iterations) */
  } graph_labelprop_result_t;

  size_t graph_algo_labelprop_workspace_size (const graph_snapshot_t * snapshot);

  graph_error_t graph_algo_labelprop (const graph_snapshot_t * snapshot,
      const graph_labelprop_params_t * params,
      const graph_pred_filter_t * pred_filter, void *workspace, graph_labelprop_result_t * result);

/* ============================================================================
 * JACCARD SIMILARITY MODES
 *
 * What two nodes are compared *by*.  The default discards the predicate and
 * compares outgoing neighbourhoods, which is the graph reading and what
 * Neo4j's gds.nodeSimilarity computes.  It is the wrong reading on a graph
 * whose edges do not all mean the same thing -- `likes` and `hates` pointing
 * at one object make two entities identical -- so the readings that keep the
 * predicate are selectable.
 *
 * A literal is in none of them.  The loader keeps edges between nodes, and a
 * literal object is not a node, so `<a> <name> "Alice"` is not in the graph
 * and no mode can see it.  These compare IRI-valued statements only.
 * ============================================================================ */

  typedef enum graph_jaccard_mode
  {
    GRAPH_JACCARD_NEIGHBOURS_OUT = 0,	/* distinct outgoing neighbours       */
    GRAPH_JACCARD_PAIRS_OUT = 1,	/* distinct (predicate, object)       */
    GRAPH_JACCARD_PAIRS_BOTH = 2,	/* ... and incoming (subject, pred)   */
    GRAPH_JACCARD_NEIGHBOURS_BOTH = 3	/* distinct neighbours, either way    */
  } graph_jaccard_mode_t;

#define GRAPH_JACCARD_MODE_MAX 3

/* ============================================================================
 * JACCARD SIMILARITY
 * ============================================================================ */

  typedef struct graph_jaccard_result
  {
    double similarity;
    uint64_t intersection;
    uint64_t union_size;
  } graph_jaccard_result_t;

  graph_error_t graph_algo_jaccard (const graph_snapshot_t * snapshot,
      graph_node_id_t node_a,
      graph_node_id_t node_b,
      graph_direction_t direction,
      const graph_pred_filter_t * pred_filter, graph_jaccard_mode_t mode, graph_jaccard_result_t * result);

  graph_error_t graph_algo_jaccard_batch (const graph_snapshot_t * snapshot,
      const graph_node_id_t * nodes_a,
      const graph_node_id_t * nodes_b,
      uint64_t pair_count,
      graph_direction_t direction, const graph_pred_filter_t * pred_filter, graph_jaccard_mode_t mode, double *similarities_out);

/* ============================================================================
 * K-MEANS CLUSTERING
 * ============================================================================ */

  typedef struct graph_kmeans_params
  {
    uint32_t k;
    int max_iterations;
    double epsilon;
    uint64_t seed;
  } graph_kmeans_params_t;

  extern const graph_kmeans_params_t GRAPH_KMEANS_DEFAULT;

  typedef struct graph_kmeans_result
  {
    uint32_t *cluster_ids;
    double *centroids;
    uint64_t node_count;
    uint32_t k;
    uint32_t dimension;
    int iterations;
    double inertia;
    bool converged;
  } graph_kmeans_result_t;

  size_t graph_algo_kmeans_workspace_size (uint64_t node_count, uint32_t k, uint32_t dimension);

  graph_error_t graph_algo_kmeans (const double *features,
      uint64_t node_count,
      uint32_t dimension, const graph_kmeans_params_t * params, void *workspace, graph_kmeans_result_t * result);

/* ============================================================================
 * KNN (K-Nearest Neighbors)
 * ============================================================================ */

  typedef struct graph_knn_result
  {
    graph_node_id_t *neighbors;
    double *distances;
    uint32_t k;
    uint32_t found;
  } graph_knn_result_t;

  size_t graph_algo_knn_workspace_size (const graph_snapshot_t * snapshot, uint32_t k);

  graph_error_t graph_algo_knn (const graph_snapshot_t * snapshot,
      graph_node_id_t source,
      uint32_t k,
      graph_direction_t direction,
      const graph_pred_filter_t * pred_filter,
      graph_weight_func_t weight_func, void *weight_user_data, void *workspace, graph_knn_result_t * result);

#ifdef __cplusplus
}
#endif

#endif				/* GRAPH_ALGO_ADVANCED_H */
