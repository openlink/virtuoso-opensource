/*
 *  bif_graph.h
 *
 *  Graph analytics BIFs
 *
 *  Internal header for the server code exposing graph algorithms as SQL functions.
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

#ifndef BIF_GRAPH_H
#define BIF_GRAPH_H

#include "graph_quad.h"
#include "sqlnode.h"

#ifdef __cplusplus
extern "C"
{
#endif

  void bif_graph_init (void);
  void vgraph_scope_init (void);

/* The compile mutex guarding compile-once query plans in
 * bif_graph_scope.c.  Exposed so the parallel executor can assert, in
 * debug builds, that a thread entering a parallel section holds no
 * graph-layer mutex (a worker slice acquiring the same mutex would
 * deadlock against the owner waiting in aq_wait_all). */
  struct mutex_s;
  extern struct mutex_s *vgraph_scope_compile_mutex (void);

/* ============================================================================
 * ERROR CODES (SQL State format)
 * ============================================================================ */

#define VGRAPH_SQLSTATE_OK           "00000"
#define VGRAPH_SQLSTATE_NULL_ARG     "42001"
#define VGRAPH_SQLSTATE_INVALID_ARG  "42002"
#define VGRAPH_SQLSTATE_NO_GRAPH     "42003"
#define VGRAPH_SQLSTATE_NO_NODE      "42004"
#define VGRAPH_SQLSTATE_NO_PRED      "42005"
#define VGRAPH_SQLSTATE_SCOPE_ERROR  "42006"
#define VGRAPH_SQLSTATE_ALGO_ERROR   "42007"
#define VGRAPH_SQLSTATE_MEMORY       "42008"
#define VGRAPH_SQLSTATE_INTERNAL     "42099"

/* ============================================================================
 * GRAPH SCOPE RESOLUTION
 * ============================================================================ */

/* Resolved scope from SPARQL execution context */
  typedef struct vgraph_resolved_scope
  {
    graph_iri_id_t *graph_iris;	/* Resolved graph IRIs */
    uint32_t graph_count;	/* Number of graphs */
    uint64_t graph_set_id;	/* Stable cache/materialization key */
    bool is_explicit;		/* Explicitly provided vs. inferred */
    bool include_default;
  } vgraph_resolved_scope_t;

/**
 * Resolve graph scope from SPARQL execution context
 * 
 * Priority:
 *   1. Explicit graph_iri argument (if not NULL)
 *   2. FROM / FROM NAMED clauses in current query
 *   3. Default graph of current dataset
 *   4. Minimal-scope fallback (error or single default graph)
 * 
 * @param qst        Query state from BIF call
 * @param graph_arg  Explicit graph IRI argument (may be NULL or DV_DB_NULL)
 * @param out_scope  Output resolved scope
 * @return GRAPH_OK or error code
 */
  graph_error_t vgraph_resolve_scope (void *qst, void *graph_arg, vgraph_resolved_scope_t * out_scope);

/**
 * Free resources allocated by scope resolution
 */
  void vgraph_scope_free (vgraph_resolved_scope_t * scope);

/**
 * Graph-level READ permission check for an already resolved scope.
 *
 * The BIF layer reads DB.DBA.RDF_QUAD with its own SQL, so the __rgs_ack
 * filter that the SPARQL compiler injects never runs on this path; this is
 * the equivalent test.  vgraph_resolve_scope() calls it for every graph it
 * resolves, so callers of that function need not repeat it.
 *
 * @return GRAPH_OK when every graph in the scope is readable,
 *         GRAPH_ERR_PERMISSION_DENIED otherwise
 */
  graph_error_t vgraph_scope_check_read_perms (void *qst, const vgraph_resolved_scope_t * scope);

/* One graph, by the same rule: SPARQL_SELECT and READ on the graph. */
  graph_error_t vgraph_graph_check_read (void *qst, graph_iri_id_t graph_iri);

/* ============================================================================
 * VIRTUOSO IRI <-> ID MAPPING
 * ============================================================================ */

/**
 * Convert Virtuoso IRI box to internal graph_iri_id_t
 * 
 * Uses Virtuoso's internal IRI_ID if available, otherwise hashes the IRI string.
 */
  graph_iri_id_t vgraph_iri_to_id (void *iri_box);

/**
 * Convert Virtuoso IRI box to internal graph_iri_id_t with query context.
 * When qst is provided, string IRIs are converted via Virtuoso's IRI_TO_ID.
 */
  graph_iri_id_t vgraph_iri_to_id_ex (void *iri_box, void *qst);

/**
 * Why the last graph load on this thread failed.
 *
 * GRAPH_ERR_IO_ERROR is returned whenever the internal SQL that materialises
 * a graph will not compile or execute, so on its own it names no cause.  The
 * loaders record the underlying error here instead of discarding it.
 *
 * _clear() is called once per load attempt, so a detail can never attach to a
 * later, unrelated failure.  _get() returns "" for a caller outside the DBA
 * group: for a table-sourced graph the text names the backing table, which is
 * server configuration rather than an answer.
 */
/* How often a loader stops to ask whether it should still be running --
 * whether the graph is over its limit, or the statement was cancelled.
 * Every row would be too often to pay for and never would be too late to
 * be a bound, so the loaders check on this stride.  Shared so that all
 * three of them use the same one. */
#define VGRAPH_LOAD_CHECK_ROWS 4096

/* A transient graph -- one built from edges the caller handed in -- gets a
 * private graph id with the top bit set, so that two sessions using the
 * same IRI cannot collide in the snapshot cache, which knows nothing about
 * sessions.  Real IRI_IDs never reach 2^63; that is exactly why a 64-bit
 * hash pasted into "G = #i<id>" was once rejected as a bad iri literal.  A
 * private id never reaches SQL, because a transient graph is never loaded
 * by a query. */
#define VGRAPH_TRANSIENT_BIT (((graph_iri_id_t) 1) << 63)
#define VGRAPH_IS_TRANSIENT(id) (0 != ((id) & VGRAPH_TRANSIENT_BIT))

/* The private id this session has registered for `graph_iri`, or 0.  A
 * registration made by another session is invisible here, which is the
 * whole access check for a transient graph. */
  graph_iri_id_t vgraph_edge_src_private_id (graph_iri_id_t graph_iri, struct client_connection_s *cli);

  void vgraph_load_error_clear (void);
  void vgraph_load_error_set (caddr_t err);
  void vgraph_load_error_set_text (const char *text);
  const char *vgraph_load_error_get (void *qst);

/**
 * Convert Virtuoso IRI box to internal graph_node_id_t
 */
  graph_node_id_t vgraph_node_to_id (void *node_box);

/**
 * Convert Virtuoso IRI box to internal graph_node_id_t with query context.
 * When qst is provided, string IRIs are converted via Virtuoso's IRI_TO_ID.
 */
  graph_node_id_t vgraph_node_to_id_ex (void *node_box, void *qst);

/* Resolve one vectored input column without executing per-row SQL. */
  graph_error_t vgraph_iri_to_id_batch (caddr_t * qst, data_col_t * node_col,
      int n_sets, graph_node_id_t * out_ids, caddr_t * err_ret);
  void vgraph_batch_resolution_begin (caddr_t * qst, graph_node_id_t * first, graph_node_id_t * second, int node_arg_count);
  void vgraph_batch_resolution_reset (void);
  void vgraph_batch_resolution_end (void);

/**
 * Convert Virtuoso IRI box to internal graph_pred_id_t
 */
  graph_pred_id_t vgraph_pred_to_id (void *pred_box);

/**
 * Convert Virtuoso IRI box to internal graph_pred_id_t with query context.
 * When qst is provided, string IRIs are converted via Virtuoso's IRI_TO_ID.
 */
  graph_pred_id_t vgraph_pred_to_id_ex (void *pred_box, void *qst);

/**
 * Convert internal graph_node_id_t back to Virtuoso IRI box.
 * Returns NULL if the ID cannot be resolved.
 */
  void *vgraph_id_to_iri_ex (graph_node_id_t node_id, void *qst);

/* ============================================================================
 * QUAD LOADING FROM RDF_QUAD
 * ============================================================================ */

/**
 * Load quads from Virtuoso RDF_QUAD table into quad store
 * 
 * @param qst         Query state
 * @param store       Destination quad store
 * @param scope       Scope filter (which graphs to load)
 * @param pred_filter Predicate filter (which predicates to include)
 * @param out_loaded  Number of quads loaded
 * @return GRAPH_OK or error code
 */
  graph_error_t vgraph_load_from_rdf_quad (void *qst,
      quad_store_t * store, const vgraph_resolved_scope_t * scope, const graph_pred_filter_t * pred_filter, uint64_t * out_loaded);

/* Load edges from `SELECT S, O FROM <table>`.  Weights, when the table
 * has them, are read separately on the first weighted call -- see the
 * comment on the definition for why they are not read here. */
  graph_error_t vgraph_load_from_table (void *qst,
      quad_store_t * store, const char *table, graph_iri_id_t graph_id, graph_pred_id_t pred_id, uint64_t * out_loaded);

/* Coerce a weight box (double, float, integer, numeric or string) to a
 * double, defaulting to 1.0. */
  double vgraph_weight_box_to_double (caddr_t weight_box);

/* True when a name may be pasted into SQL text: up to three dot-separated
 * plain identifiers and nothing else.  The whole injection defence for the
 * table loader and the weight-column reader, and deliberately narrower
 * than what SQL would accept. */
  bool vgraph_table_name_ok (const char *name);

/* Resolve an IRI string to its id, minting one if unseen.  Only for the
 * table loader's synthetic predicate; everything else must use the
 * if-known form. */
  graph_node_id_t vgraph_iri_to_id_create (void *iri_box, void *qst);

/**
 * Resolve (once, cached) the IRI IDs of the RDF reification vocabulary -
 * rdf:subject, rdf:predicate, rdf:object, rdf:reifies - for use by
 * all-predicates quad loads, which must exclude them.
 *
 * @param qst      Query state (may be NULL; IDs stay 0 until a context
 *                 is available)
 * @param subj     Out: rdf:subject IRI ID
 * @param pred     Out: rdf:predicate IRI ID
 * @param obj      Out: rdf:object IRI ID
 * @param reifies  Out: rdf:reifies IRI ID
 */
  extern void vgraph_reification_vocab_ids (void *qst, graph_iri_id_t * subj,
      graph_iri_id_t * pred, graph_iri_id_t * obj, graph_iri_id_t * reifies);

/**
 * Load quads from a pre-loaded Virtuoso vector into quad store.
 * Used when PL wrapper procedures pre-load data via PL cursors
 * (which work reliably from within SPARQL evaluation).
 *
 * @param store        Destination quad store
 * @param graph_id     Graph IRI ID to assign to loaded quads
 * @param quad_vector  Virtuoso vector of 3-element sub-vectors [[S,P,O], ...]
 * @param out_loaded   Number of quads loaded
 * @return GRAPH_OK or error code
 */
  graph_error_t vgraph_load_from_vector (quad_store_t * store, graph_iri_id_t graph_id, void *quad_vector, uint64_t * out_loaded);

  graph_error_t vgraph_load_from_vector_ex (quad_store_t * store,
      graph_iri_id_t graph_id, void *quad_vector, void *qst, uint64_t * out_loaded);

/* ============================================================================
 * WORKSPACE MANAGEMENT
 * ============================================================================ */

/**
 * Get or allocate a workspace for the given algorithm
 * 
 * Workspaces are cached per-thread to avoid repeated allocations.
 */
  void *vgraph_get_workspace (size_t required_size);

/* Current [Graph] MaxWorkspace budget, in bytes. */
  size_t vgraph_workspace_limit (void);

/* [Graph] MaxNodes and [Graph] MaxTriples, as the loader sees them.
 * A triple limit of 0 means unlimited. */
  uint64_t vgraph_max_nodes_limit (void);
  uint64_t vgraph_max_triples_limit (void);

/**
 * Return workspace to cache
 */
  void vgraph_return_workspace (void *workspace);

/* ============================================================================
 * RESULT BOXING
 * ============================================================================ */

/**
 * Box algorithm result as Virtuoso array
 */
  void *vgraph_box_double_array (const double *values, uint64_t count);

/**
 * Box algorithm result as Virtuoso integer array
 */
  void *vgraph_box_int_array (const uint64_t * values, uint64_t count);

/**
 * Box single double result
 */
  void *vgraph_box_double (double value);

/**
 * Box single integer result
 */
  void *vgraph_box_integer (int64_t value);

#ifdef __cplusplus
}
#endif

#endif				/* BIF_GRAPH_H */
