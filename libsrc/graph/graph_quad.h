/*
 *  graph_quad.h
 *
 *  RDF Quad Extension for Graph Library
 *
 *  Extends the triple-based graph library to support RDF Quads:
 *    (Graph, Subject, Predicate, Object)
 *
 *  The Graph IRI becomes a first-class scope key enabling:
 *    - Per-graph adjacency isolation
 *    - Fast graph-scoped queries without global scans
 *    - Multi-graph dataset operations when explicitly requested
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

#ifndef GRAPH_QUAD_H
#define GRAPH_QUAD_H

#include "graph.h"

#ifdef __cplusplus
extern "C"
{
#endif

/* ============================================================================
 * QUAD MODEL
 * ============================================================================ */

/* Graph IRI identifier (same type as node IDs for uniformity) */
  typedef uint64_t graph_iri_id_t;

#define GRAPH_IRI_ID_INVALID  ((graph_iri_id_t)0)
#define GRAPH_IRI_ID_DEFAULT  ((graph_iri_id_t)1)	/* Default graph */

/* RDF Quad: (Graph, Subject, Predicate, Object) */
  typedef struct graph_quad
  {
    graph_iri_id_t graph;
    graph_node_id_t subject;
    graph_pred_id_t predicate;
    graph_node_id_t object;
  } graph_quad_t;

/* ============================================================================
 * QUAD STORE HANDLE
 * ============================================================================ */

  typedef struct quad_store quad_store_t;

/* Quad store configuration */
  typedef struct quad_store_config
  {
    uint64_t initial_graph_capacity;	/* Expected number of named graphs */
    uint64_t initial_quad_capacity;	/* Expected total quads */
    bool build_graph_index;	/* Index by graph IRI */
    bool lazy_graph_creation;	/* Create graphs on first quad insert */
    graph_allocator_t allocator;	/* Custom allocator */
  } quad_store_config_t;

  extern const quad_store_config_t QUAD_STORE_CONFIG_DEFAULT;

/* ============================================================================
 * QUAD STORE LIFECYCLE
 * ============================================================================ */

/**
 * Create a new quad store
 */
  graph_error_t quad_store_create (const quad_store_config_t * config, quad_store_t ** out_store);

/**
 * Destroy a quad store and all contained graphs
 */
  graph_error_t quad_store_destroy (quad_store_t * store);

/**
 * Get or create a named graph within the quad store
 */
  graph_error_t quad_store_get_graph (quad_store_t * store, graph_iri_id_t graph_iri, bool create_if_missing, graph_t ** out_graph);

/**
 * Check if a named graph exists
 */
  bool quad_store_graph_exists (const quad_store_t * store, graph_iri_id_t graph_iri);

/**
 * List all graph IRIs in the store
 */
  graph_error_t quad_store_list_graphs (const quad_store_t * store,
      graph_iri_id_t * out_iris, uint64_t max_count, uint64_t * out_count);

/**
 * Get count of named graphs
 */
  uint64_t quad_store_graph_count (const quad_store_t * store);

/* ============================================================================
 * QUAD OPERATIONS
 * ============================================================================ */

/**
 * Add a quad to the store (creates graph if lazy creation enabled)
 */
  graph_error_t quad_store_add_quad (quad_store_t * store, const graph_quad_t * quad);

/**
 * Remove a quad from the store
 */
  graph_error_t quad_store_remove_quad (quad_store_t * store, const graph_quad_t * quad);

/**
 * Add multiple quads (batched for efficiency)
 */
  graph_error_t quad_store_add_quads (quad_store_t * store, const graph_quad_t * quads, uint64_t count, uint64_t * out_added);

/**
 * Commit all pending mutations across all graphs
 */
  graph_error_t quad_store_commit (quad_store_t * store);

/**
 * Distinct nodes and quads currently held for one graph of the store.
 *
 * Lets a bulk loader enforce a size limit while it is still reading,
 * instead of materialising the whole graph and then refusing it.
 */
  graph_error_t quad_store_graph_counts (quad_store_t * store,
      graph_iri_id_t graph_iri, uint64_t * out_nodes, uint64_t * out_quads);

/* ============================================================================
 * SCOPED SNAPSHOT
 * ============================================================================ */

/* Scope for snapshot creation */
  typedef struct quad_scope
  {
    graph_iri_id_t *graph_iris;	/* Array of graph IRIs to include */
    uint32_t graph_count;	/* Number of graphs (0 = all graphs) */
    bool include_default;	/* Include default graph */
  } quad_scope_t;

#define QUAD_SCOPE_ALL      ((quad_scope_t*)NULL)
#define QUAD_SCOPE_DEFAULT  (&(quad_scope_t){NULL, 0, true})

/**
 * Create a scoped snapshot covering specified graphs
 */
  graph_error_t quad_store_snapshot_create (quad_store_t * store, const quad_scope_t * scope, graph_snapshot_t ** out_snapshot);

/* ============================================================================
 * STATISTICS
 * ============================================================================ */

  typedef struct quad_store_stats
  {
    uint64_t graph_count;
    uint64_t total_quad_count;
    uint64_t total_node_count;
    uint64_t total_predicate_count;
    uint64_t memory_bytes;
  } quad_store_stats_t;

  graph_error_t quad_store_get_stats (const quad_store_t * store, quad_store_stats_t * out_stats);

#ifdef __cplusplus
}
#endif

#endif				/* GRAPH_QUAD_H */
