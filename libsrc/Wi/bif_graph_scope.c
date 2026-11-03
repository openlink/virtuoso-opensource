/*
 *  bif_graph_scope.c
 *
 *  Graph scope resolution for the graph analytics BIFs
 *
 *  Resolves the graph scope for algorithm execution from:
 *    1. Explicit graph IRI argument
 *    2. SPARQL FROM / FROM NAMED clauses
 *    3. Default graph of current dataset
 *    4. Minimal-scope fallback
 *
 *  CRITICAL: A query scoped to a graph MUST NEVER scan the entire RDF store.
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
#include "sqlnode.h"
#include "security.h"		/* sec_bif_caller_is_dba() */
#include "sqlbif.h"
#include "rdf_core.h"
#include <stdlib.h>
#include <string.h>

static int
vgraph_iri_id_compare (const void *left, const void *right)
{
  const graph_iri_id_t a = *(const graph_iri_id_t *) left;
  const graph_iri_id_t b = *(const graph_iri_id_t *) right;
  return a < b ? -1 : a > b;
}

/* Identity of a multi-graph FROM set.
 *
 * A single graph keeps its own IRI id (the caller handles that case), so
 * this is only reached for a set.  The result is a hash, and it is used
 * both as the graph key inside the private quad store and as part of the
 * snapshot cache key, so it must never be mistaken for a real IRI id.
 * Virtuoso IRI ids do not use the top bit, so setting it puts every set id
 * in a range no single graph can occupy.  The set's size goes into the
 * cache key as well, so sets of different sizes cannot collide either. */
#define VGRAPH_SET_ID_TAG (((uint64_t) 1) << 63)

static uint64_t
vgraph_scope_set_id (graph_iri_id_t *iris, uint32_t count)
{
  uint64_t hash = 14695981039346656037ULL;
  uint32_t inx;
  if (!count)
    return GRAPH_IRI_ID_DEFAULT;
  qsort (iris, count, sizeof (*iris), vgraph_iri_id_compare);
  for (inx = 0; inx < count; inx++)
    {
      uint64_t value = iris[inx];
      unsigned byte_inx;
      for (byte_inx = 0; byte_inx < sizeof (value); byte_inx++)
	{
	  hash ^= (uint8_t) (value >> (byte_inx * 8));
	  hash *= 1099511628211ULL;
	}
    }
  hash ^= (uint64_t) count *1099511628211ULL;
  return hash | VGRAPH_SET_ID_TAG;
}

/* ============================================================================
 * IRI HASHING (FNV-1a)
 * ============================================================================ */

static uint64_t
fnv1a_hash (const char *str, size_t len)
{
  uint64_t h = 14695981039346656037ULL;
  for (size_t i = 0; i < len; i++)
    {
      h ^= (uint8_t) str[i];
      h *= 1099511628211ULL;
    }
  return h;
}

/* ============================================================================
 * STRING IRI TO IRI_ID CONVERSION VIA SQL
 * 
 * When a string IRI is passed, we need to convert it to Virtuoso's internal
 * IRI_ID using the IRI_TO_ID SQL function. This ensures consistency with
 * data loaded from RDF_QUAD which uses IRI_IDs.
 * ============================================================================ */

static dk_mutex_t *g_iri_to_id_compile_mtx = NULL;

typedef struct vgraph_batch_resolution_state
{
  caddr_t *qst;
  graph_node_id_t *ids[2];
  int node_arg_count;
  int next_arg;
} vgraph_batch_resolution_state_t;

static __thread vgraph_batch_resolution_state_t g_batch_resolution;

/* ============================================================================
 * WHY A LOAD FAILED
 *
 * GRAPH_ERR_IO_ERROR is what the loaders return whenever the internal SQL
 * they run to materialise a graph will not compile or execute: a backing
 * table dropped underneath a table-sourced graph, a cancelled query, a lock
 * that could not be taken.  Every one of those sites used to dk_free_tree()
 * the real error and hand back the bare code, so "failed to load graph:
 * I/O error" was the whole story and no caller could tell which cause it
 * was.
 *
 * The text is kept here instead, per thread, for the BIF that is about to
 * format its error to pick up.  A fixed buffer, written only on the failure
 * path: nothing is allocated, and a successful load touches one byte to
 * clear it.
 *
 * Not shown to callers outside the DBA group.  For a table-sourced graph
 * the text names the backing table, and which table stands behind a graph
 * is server configuration -- not something to be learned by naming the
 * graph and reading the error.  They get the unadorned reason.
 * ========================================================================= */

#define VGRAPH_LOAD_ERR_MAX 256
static __thread char g_load_err_detail[VGRAPH_LOAD_ERR_MAX];

void
vgraph_load_error_clear (void)
{
  g_load_err_detail[0] = '\0';
}

/* Remember `err`, a Virtuoso error box, as the reason the current load
 * failed.  Copies the text out: the caller frees the box as it always did,
 * and this must not extend its lifetime. */
void
vgraph_load_error_set (caddr_t err)
{
  const char *state, *msg;
  if (!err || DV_ARRAY_OF_POINTER != DV_TYPE_OF (err) || BOX_ELEMENTS (err) < 3)
    return;
  state = ERR_STATE (err);
  msg = ERR_MESSAGE (err);
  if (!msg || !IS_STRING_DTP (DV_TYPE_OF (msg)))
    return;
  if (state && IS_STRING_DTP (DV_TYPE_OF (state)))
    snprintf (g_load_err_detail, sizeof (g_load_err_detail), "%.20s %.200s", state, msg);
  else
    snprintf (g_load_err_detail, sizeof (g_load_err_detail), "%.200s", msg);
}

/* A fixed reason, for the failures that have no error box of their own. */
void
vgraph_load_error_set_text (const char *text)
{
  if (!text)
    return;
  snprintf (g_load_err_detail, sizeof (g_load_err_detail), "%.200s", text);
}

/* The detail, or "" when there is none or the caller may not see it. */
const char *
vgraph_load_error_get (void *qst)
{
  query_instance_t *qi = (query_instance_t *) qst;
  if (!g_load_err_detail[0])
    return "";
  if (!qi || !sec_bif_caller_is_dba (qi))
    return "";
  return g_load_err_detail;
}

void
vgraph_batch_resolution_begin (caddr_t *qst, graph_node_id_t *first, graph_node_id_t *second, int node_arg_count)
{
  g_batch_resolution.qst = qst;
  g_batch_resolution.ids[0] = first;
  g_batch_resolution.ids[1] = second;
  g_batch_resolution.node_arg_count = node_arg_count;
  g_batch_resolution.next_arg = 0;
}

void
vgraph_batch_resolution_reset (void)
{
  g_batch_resolution.next_arg = 0;
}

void
vgraph_batch_resolution_end (void)
{
  memset (&g_batch_resolution, 0, sizeof (g_batch_resolution));
}

void
vgraph_scope_init (void)
{
  if (!g_iri_to_id_compile_mtx)
    g_iri_to_id_compile_mtx = mutex_allocate ();
}

dk_mutex_t *
vgraph_scope_compile_mutex (void)
{
  return g_iri_to_id_compile_mtx;
}

static iri_id_t
string_iri_to_virtuoso_id (caddr_t *qst, const char *iri_str, size_t len)
{
  caddr_t iri_box;
  caddr_t id_box;
  caddr_t err = NULL;
  iri_id_t result = 0;
  if (!qst || !iri_str || len == 0)
    return 0;

  /* Strip angle brackets if present: <http://...> -> http://... */
  const char *clean_iri = iri_str;
  size_t clean_len = len;
  if (len >= 2 && iri_str[0] == '<' && iri_str[len - 1] == '>')
    {
      clean_iri = iri_str + 1;
      clean_len = len - 2;
    }

  iri_box = dk_alloc_box (clean_len + 1, DV_STRING);
  if (!iri_box)
    return 0;
  memcpy (iri_box, clean_iri, clean_len);
  iri_box[clean_len] = '\0';
  id_box = iri_to_id (qst, iri_box, IRI_TO_ID_IF_KNOWN, &err);
  if (!err && id_box && (DV_TYPE_OF (id_box) == DV_IRI_ID || DV_TYPE_OF (id_box) == DV_IRI_ID_8))
    result = unbox_iri_id (id_box);
  if (err)
    dk_free_tree (err);
  if (id_box)
    dk_free_tree (id_box);
  dk_free_box (iri_box);
  return result;
}

graph_error_t
vgraph_iri_to_id_batch (caddr_t *qst, data_col_t *node_col, int n_sets, graph_node_id_t *out_ids, caddr_t *err_ret)
{
  int inx;
  if (!qst || !node_col || !out_ids || n_sets < 0)
    return GRAPH_ERR_NULL_PTR;
  /* A column that cannot be read row by row.  A variable bound in only
     one branch of a UNION arrives this way -- BIND under UNION produces
     it, and so does a federated SERVICE result.
     dc_any_null is set, saying some rows are null, while dc_nulls was
     never allocated, so DC_IS_NULL() -- which tests dc_any_null and
     then indexes dc_nulls -- loads a byte from address zero.  Every
     loop below starts with that test, both the unboxed fast path and
     the boxed one, so there is no reading of this column that is safe.
     Refusing here sends the caller to the scalar path, which reports
     the argument as NULL the way it always did below the vectoring
     threshold. */
  if (!node_col->dc_values || (node_col->dc_any_null && !node_col->dc_nulls))
    return GRAPH_ERR_NULL_PTR;
  /* An unboxed column of 64-bit values, whether it is typed as an
   * IRI_ID or as a plain integer.  The integer case is not a
   * convenience: a graph loaded from a SQL table takes the column values
   * *as* its node ids, so a vertex table addressing that graph holds
   * BIGINTs, and the scalar resolver has always accepted them.  Without
   * this the same query answered correctly below the vectoring threshold
   * and failed above it -- 'node column must contain IRIs or IRI
   * strings' at 633,432 rows and a right answer at ten. */
  if (!(node_col->dc_type & DCT_BOXES) &&
      (node_col->dc_dtp == DV_IRI_ID || node_col->dc_dtp == DV_IRI_ID_8 || node_col->dc_dtp == DV_LONG_INT))
    {
      const int64 *values = (const int64 *) node_col->dc_values;
      for (inx = 0; inx < n_sets; inx++)
	out_ids[inx] = (DC_IS_NULL (node_col, inx) || values[inx] <= 0) ? GRAPH_NODE_ID_INVALID : (graph_node_id_t) values[inx];
      return GRAPH_OK;
    }
  for (inx = 0; inx < n_sets; inx++)
    {
      caddr_t value;
      caddr_t id_box = NULL;
      caddr_t iri_err = NULL;
      int tag;
      if (DC_IS_NULL (node_col, inx))
	{
	  out_ids[inx] = GRAPH_NODE_ID_INVALID;
	  continue;
	}
      value = dc_box (node_col, inx);
      tag = DV_TYPE_OF (value);
      if (tag == DV_IRI_ID || tag == DV_IRI_ID_8)
	out_ids[inx] = (graph_node_id_t) unbox_iri_id (value);
      else if (tag == DV_LONG_INT || tag == DV_SHORT_INT)
	{
	  /* The same as the unboxed case above, and the same rule the
	   * scalar vgraph_node_to_id_ex() applies: a non-positive value
	   * is not a node id, because GRAPH_NODE_ID_INVALID is 0. */
	  int64 v = unbox (value);
	  out_ids[inx] = (v > 0) ? (graph_node_id_t) v : GRAPH_NODE_ID_INVALID;
	}
      else if (tag == DV_STRING || tag == DV_SHORT_STRING || tag == DV_LONG_STRING || tag == DV_UNAME)
	{
	  id_box = iri_to_id (qst, value, IRI_TO_ID_IF_KNOWN, &iri_err);
	  if (iri_err)
	    {
	      if (err_ret)
		*err_ret = iri_err;
	      dk_free_tree (value);
	      return GRAPH_ERR_INVALID_ID;
	    }
	  out_ids[inx] = id_box &&
	      (DV_TYPE_OF (id_box) == DV_IRI_ID || DV_TYPE_OF (id_box) == DV_IRI_ID_8) ?
	      (graph_node_id_t) unbox_iri_id (id_box) : GRAPH_NODE_ID_INVALID;
	}
      else if (tag == DV_DB_NULL)
	out_ids[inx] = GRAPH_NODE_ID_INVALID;
      else
	{
	  if (err_ret)
	    *err_ret = srv_make_new_error (VGRAPH_SQLSTATE_INVALID_ARG,
		"VGBAT01", "Graph algorithm node column must contain IRIs, " "IRI strings or integer node ids");
	  dk_free_tree (value);
	  return GRAPH_ERR_INVALID_PARAM;
	}
      if (id_box)
	dk_free_tree (id_box);
      dk_free_tree (value);
    }
  return GRAPH_OK;
}

/* ============================================================================
 * VIRTUOSO TYPE CONVERSION
 * ============================================================================ */

/* 
 * Convert IRI box to graph_iri_id_t with query context for string IRI resolution.
 * When qst is provided, string IRIs are converted via Virtuoso's IRI_TO_ID.
 * When qst is NULL, string IRIs are hashed (for standalone/test builds).
 */
graph_iri_id_t
vgraph_iri_to_id_ex (void *iri_box, void *qst)
{
  /* DEFENSE-IN-DEPTH: Handle NULL pointer */
  if (!iri_box)
    return GRAPH_IRI_ID_INVALID;

  int tag = DV_TYPE_OF (iri_box);

  /* CRITICAL: Handle DB_NULL first - SQL NULL maps to default graph */
  if (tag == DV_DB_NULL)
    {
      return GRAPH_IRI_ID_DEFAULT;
    }

  /* Handle IRI_ID directly (most efficient) */
  if (tag == DV_IRI_ID || tag == DV_IRI_ID_8)
    {
      iri_id_t iid = unbox_iri_id (iri_box);
      if (iid == 0)
	return GRAPH_IRI_ID_DEFAULT;
      return (graph_iri_id_t) iid;
    }

  /* Handle integer - the SQL constant the SPARQL translator emits for
   * an omitted graph/predicate argument arrives as an integer box, and
   * the SQL form passes graphs as iri_to_id() integers.  A non-positive
   * value means "no graph specified", not an invalid ID. */
  if (tag == DV_LONG_INT || tag == DV_SHORT_INT)
    {
      int64_t val = unbox (iri_box);
      if (val <= 0)
	return GRAPH_IRI_ID_DEFAULT;
      return (graph_iri_id_t) val;
    }

  /* Handle string IRI - convert via Virtuoso IRI_TO_ID if qst available */
  if (tag == DV_STRING || tag == DV_SHORT_STRING || tag == DV_LONG_STRING || tag == DV_UNAME)
    {
      const char *str = (const char *) iri_box;
      size_t len = box_length (iri_box);
      if (!str || len == 0)
	return GRAPH_IRI_ID_DEFAULT;

      /* With a query context the store is the authority: an IRI that no
       * triple has ever used is not a graph, and GRAPH_IRI_ID_INVALID is
       * the whole answer.  string_iri_to_virtuoso_id() already returns 0
       * for that, and GRAPH_IRI_ID_INVALID is 0, so its result stands as
       * written.  This is what vgraph_node_to_id_ex() does a few lines
       * below, and the two must agree.
       *
       * It must NOT fall through to the hash.  graph_iri_id_t is a
       * uint64, so a hash slots in unnoticed and two things go wrong.
       * vgraph_load_from_rdf_quad() pastes the id into
       * "WHERE G = #i<id>": any value with the top bit set is outside the
       * signed-64 IRI_ID range, so sql_compile() fails with SQ074 and the
       * caller reports the generic "I/O error" -- which is why a missing
       * graph used to be an I/O error for about half of all names and a
       * clean "Not found" for the rest, decided by the hash of the name.
       * On the other half, a collision with a real IRI_ID would scope the
       * call to a graph the caller never named. */
      if (qst)
	return (graph_iri_id_t) string_iri_to_virtuoso_id (qst, str, len);

      /* No query context: an embedder, or a standalone build with no
       * store to ask.  Hashing the name is the only identity available,
       * and these ids only have to be consistent within that process. */
      uint64_t id = fnv1a_hash (str, len);
      return id ? id : 1;
    }

  return GRAPH_IRI_ID_INVALID;
}

/* Legacy wrapper without query context */
graph_iri_id_t
vgraph_iri_to_id (void *iri_box)
{
  return vgraph_iri_to_id_ex (iri_box, NULL);
}

/*
 * Convert node box to graph_node_id_t with query context for string IRI resolution.
 * When qst is provided, string IRIs are converted via Virtuoso's IRI_TO_ID.
 * When qst is NULL, string IRIs are hashed (for standalone/test builds).
 */
graph_node_id_t
vgraph_node_to_id_ex (void *node_box, void *qst)
{
  if (qst && g_batch_resolution.qst == qst && g_batch_resolution.next_arg < g_batch_resolution.node_arg_count)
    {
      query_instance_t *qi = (query_instance_t *) qst;
      graph_node_id_t *ids = g_batch_resolution.ids[g_batch_resolution.next_arg++];
      if (ids)
	return ids[qi->qi_set];
    }
  /* DEFENSE-IN-DEPTH: Handle NULL pointer */
  if (!node_box)
    return GRAPH_NODE_ID_INVALID;

  int tag = DV_TYPE_OF (node_box);

  /* CRITICAL: Handle DB_NULL explicitly - this is different from C NULL */
  if (tag == DV_DB_NULL)
    {
      return GRAPH_NODE_ID_INVALID;
    }

  /* Handle IRI_ID - use unbox_iri_id for proper extraction */
  if (tag == DV_IRI_ID || tag == DV_IRI_ID_8)
    {
      iri_id_t iid = unbox_iri_id (node_box);
      if (iid == 0)
	return GRAPH_NODE_ID_INVALID;
      return (graph_node_id_t) iid;
    }

  /* Handle integer - Virtuoso may box IRI_IDs as integers in some contexts.
   * Use unbox_iri_int64 if available, otherwise treat as raw integer ID */
  if (tag == DV_LONG_INT || tag == DV_SHORT_INT)
    {
      /* Try to get value that matches what unbox_iri_id would return */
      int64_t val = unbox (node_box);
      if (val <= 0)
	return GRAPH_NODE_ID_INVALID;
      return (graph_node_id_t) val;
    }

  /* Handle boxed IRI - RDF IRI references (not literals).
   * DV_RDF is an RDF literal (string, typed literal, etc.) and
   * must NOT be treated as a graph node.  Only DV_RDF_ID and
   * DV_RDF_ID_8 are IRI references stored as IRI IDs. */
  if (tag == DV_RDF_ID || tag == DV_RDF_ID_8)
    {
      iri_id_t iid = unbox_iri_id (node_box);
      if (iid == 0)
	return GRAPH_NODE_ID_INVALID;
      return (graph_node_id_t) iid;
    }

  /* Handle string IRI - convert via Virtuoso IRI_TO_ID if qst available */
  if (tag == DV_STRING || tag == DV_SHORT_STRING || tag == DV_LONG_STRING || tag == DV_UNAME)
    {
      const char *str = (const char *) node_box;
      size_t len = box_length (node_box);
      if (!str || len == 0)
	return GRAPH_NODE_ID_INVALID;

      /* If we have query context, use Virtuoso's IRI_TO_ID for proper resolution */
      if (qst)
	{
	  iri_id_t virt_id = string_iri_to_virtuoso_id (qst, str, len);
	  if (virt_id != 0)
	    {
	      return (graph_node_id_t) virt_id;
	    }
	  /* IRI not found - return INVALID (node doesn't exist) */
	  return GRAPH_NODE_ID_INVALID;
	}

      /* Fallback: hash the string (for standalone builds) */
      uint64_t id = fnv1a_hash (str, len);
      return id ? id : 1;
    }

  /* Unknown type - reject safely */
  return GRAPH_NODE_ID_INVALID;
}

/* Legacy wrapper without query context */
graph_node_id_t
vgraph_node_to_id (void *node_box)
{
  return vgraph_node_to_id_ex (node_box, NULL);
}

graph_pred_id_t
vgraph_pred_to_id_ex (void *pred_box, void *qst)
{
  /* Same logic as node - predicates are also IRIs */
  return (graph_pred_id_t) vgraph_node_to_id_ex (pred_box, qst);
}

/* Resolve an IRI string to its id, minting one if it has never been seen.
 *
 * Everything else in this file resolves IRIs with IRI_TO_ID_IF_KNOWN,
 * because asking about a node that does not exist should answer "no such
 * node" rather than quietly create one.  A graph loaded from a table is
 * the exception: its predicate names an edge kind that exists only in the
 * table and so, by construction, has never been an RDF subject, predicate
 * or object.  Refusing to mint it would mean no table-sourced graph could
 * be loaded without a preparatory iri_to_id() call whose only purpose is
 * to work around this. */
graph_node_id_t
vgraph_iri_to_id_create (void *iri_box, void *qst)
{
  caddr_t id_box, err = NULL;
  graph_node_id_t out = GRAPH_NODE_ID_INVALID;
  int tag;
  if (!iri_box || !qst)
    return GRAPH_NODE_ID_INVALID;
  tag = DV_TYPE_OF (iri_box);
  if (tag != DV_STRING && tag != DV_SHORT_STRING && tag != DV_LONG_STRING && tag != DV_UNAME)
    return vgraph_node_to_id_ex (iri_box, qst);	/* already an id */
  id_box = iri_to_id ((caddr_t *) qst, (caddr_t) iri_box, IRI_TO_ID_WITH_CREATE, &err);
  if (!err && id_box && (DV_TYPE_OF (id_box) == DV_IRI_ID || DV_TYPE_OF (id_box) == DV_IRI_ID_8))
    out = (graph_node_id_t) unbox_iri_id (id_box);
  if (err)
    dk_free_tree (err);
  if (id_box)
    dk_free_tree (id_box);
  return out;
}

graph_pred_id_t
vgraph_pred_to_id (void *pred_box)
{
  return vgraph_pred_to_id_ex (pred_box, NULL);
}

/* ============================================================================
 * ID TO IRI CONVERSION (reverse mapping)
 * ============================================================================ */

/* Cached parameterized query for ID_TO_IRI - compiled once, reused forever */
static query_t *g_id_to_iri_qr = NULL;
static const char *ID_TO_IRI_SQL = "SELECT ID_TO_IRI(?)";

/**
 * Convert internal graph_node_id_t back to Virtuoso IRI box.
 * Uses Virtuoso's ID_TO_IRI SQL function with parameterized query.
 */
void *
vgraph_id_to_iri_ex (graph_node_id_t node_id, void *qst)
{
  if (node_id == GRAPH_NODE_ID_INVALID || node_id == 0)
    return NULL;
  if (!qst)
    return NULL;

  client_connection_t *cli = sqlc_client ();
  if (!cli)
    return NULL;

  /* Compile query once and cache it. */
  vgraph_scope_init ();
  mutex_enter (g_iri_to_id_compile_mtx);
  if (!g_id_to_iri_qr)
    {
      caddr_t compile_err = NULL;
      g_id_to_iri_qr = sql_compile_static (ID_TO_IRI_SQL, cli, &compile_err, SQLC_DEFAULT);
      if (compile_err)
	{
	  dk_free_tree (compile_err);
	  mutex_leave (g_iri_to_id_compile_mtx);
	  return NULL;
	}
    }
  mutex_leave (g_iri_to_id_compile_mtx);
  if (!g_id_to_iri_qr)
    return NULL;

  /* Create boxed IRI_ID parameter */
  caddr_t id_box = box_iri_id ((iri_id_t) node_id);
  if (!id_box)
    return NULL;

  local_cursor_t *lc = NULL;
  caddr_t exec_err = NULL;
  exec_err = qr_rec_exec (g_id_to_iri_qr, cli, &lc, (query_instance_t *) qst, NULL, 1, ":0", id_box, QRP_RAW);
  if (exec_err || !lc)
    {
      if (exec_err)
	dk_free_tree (exec_err);
      /* sql_compile_static queries are freed at server shutdown */
      return NULL;
    }

  caddr_t result = NULL;
  if (lc_next (lc))
    {
      caddr_t iri_box = lc_nth_col (lc, 0);
      if (iri_box && DV_TYPE_OF (iri_box) != DV_DB_NULL)
	{
	  /* Copy the IRI string to return */
	  result = box_copy (iri_box);
	}
    }

  lc_free (lc);
  return result;
}

/* ============================================================================
 * SCOPE RESOLUTION
 * ============================================================================ */

/*
 * Read permission for the analytics BIFs: what SPARQL asks, for the user
 * SPARQL would run as (spar_boxed_exec_uid: the connection's user, dba for
 * the bootstrap connection, nobody when there is none).
 *
 *   - the SPARQL_SELECT role, which is granted RDF_QUAD and has to be
 *     granted every GRAPH_LOAD_TABLE source;
 *   - READ on the graph, rdf_graph_configured_perms(), which is what the
 *     __rgs_ack filter the SPARQL compiler adds for every graph runs.
 *
 * The loaders read with their own SQL and the shared cache answers without
 * loading, so neither would ask on their own.  Denial reads as "not found",
 * so it cannot be used to probe for graphs.  A transient graph is the
 * session's own edges and has no RDF graph to ask about.
 */
graph_error_t
vgraph_graph_check_read (void *qst, graph_iri_id_t graph_iri)
{
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli;
  user_t *u;
  caddr_t boxed;
  int perms;

  /* No query context means an embedder call, not a user request. */
  if (!qi)
    return GRAPH_OK;
  if (VGRAPH_IS_TRANSIENT (graph_iri))
    return GRAPH_OK;
  cli = qi->qi_client;
  if (!cli)
    return GRAPH_ERR_PERMISSION_DENIED;
  if (cli == bootstrap_cli)
    return GRAPH_OK;
  u = cli->cli_user ? cli->cli_user : sec_id_to_user (U_ID_NOBODY);
  if (!u)
    return GRAPH_ERR_PERMISSION_DENIED;
  if (sec_user_has_group (U_ID_DBA, u->usr_id) || sec_user_has_group (G_ID_DBA, u->usr_g_id))
    return GRAPH_OK;
  if (!sec_user_has_group_name ("SPARQL_SELECT", u->usr_id))
    return GRAPH_ERR_PERMISSION_DENIED;
  boxed = box_iri_id ((iri_id_t) graph_iri);
  perms = rdf_graph_configured_perms (qi, boxed, u, 1, RDF_GRAPH_PERM_READ);
  dk_free_box (boxed);
  return (perms & RDF_GRAPH_PERM_READ) ? GRAPH_OK : GRAPH_ERR_PERMISSION_DENIED;
}

graph_error_t
vgraph_scope_check_read_perms (void *qst, const vgraph_resolved_scope_t *scope)
{
  uint32_t inx;
  graph_error_t err;

  if (!scope)
    return GRAPH_ERR_NULL_PTR;
  for (inx = 0; inx < scope->graph_count; inx++)
    {
      err = vgraph_graph_check_read (qst, scope->graph_iris[inx]);
      if (err != GRAPH_OK)
	return err;
    }
  return GRAPH_OK;
}

static graph_error_t vgraph_resolve_scope_int (void *qst, void *graph_arg, vgraph_resolved_scope_t * out_scope);

graph_error_t
vgraph_resolve_scope (void *qst, void *graph_arg, vgraph_resolved_scope_t *out_scope)
{
  graph_error_t err = vgraph_resolve_scope_int (qst, graph_arg, out_scope);
  if (err != GRAPH_OK)
    return err;
  err = vgraph_scope_check_read_perms (qst, out_scope);
  if (err != GRAPH_OK)
    {
      vgraph_scope_free (out_scope);
      return err;
    }
  return GRAPH_OK;
}

static graph_error_t
vgraph_resolve_scope_int (void *qst, void *graph_arg, vgraph_resolved_scope_t *out_scope)
{
  if (!out_scope)
    return GRAPH_ERR_NULL_PTR;

  memset (out_scope, 0, sizeof (*out_scope));

  /* Case A: Explicit graph argument provided */
  if (graph_arg && DV_TYPE_OF (graph_arg) != DV_DB_NULL)
    {
      /* Vector argument: the SPARQL translator passes a multi-FROM
       * dataset as vector('iri', ...); scope the BIF to every graph. */
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (graph_arg))
	{
	  uint32_t n = (uint32_t) BOX_ELEMENTS (graph_arg);
	  uint32_t inx;
	  if (!n)
	    {
	      out_scope->graph_iris = dk_alloc (sizeof (graph_iri_id_t));
	      if (!out_scope->graph_iris)
		return GRAPH_ERR_OUT_OF_MEMORY;
	      out_scope->graph_iris[0] = GRAPH_IRI_ID_DEFAULT;
	      out_scope->graph_count = 1;
	      out_scope->graph_set_id = GRAPH_IRI_ID_DEFAULT;
	      out_scope->is_explicit = false;
	      out_scope->include_default = true;
	      return GRAPH_OK;
	    }
	  out_scope->graph_iris = dk_alloc (n * sizeof (graph_iri_id_t));
	  if (!out_scope->graph_iris)
	    return GRAPH_ERR_OUT_OF_MEMORY;
	  for (inx = 0; inx < n; inx++)
	    {
	      graph_iri_id_t gid = vgraph_iri_to_id_ex (((caddr_t *) graph_arg)[inx], qst);
	      if (GRAPH_IRI_ID_INVALID == gid)
		{
		  dk_free (out_scope->graph_iris, n * sizeof (graph_iri_id_t));
		  out_scope->graph_iris = NULL;
		  /* "Not found", for the reason given at the scalar case. */
		  return GRAPH_ERR_NOT_FOUND;
		}
	      out_scope->graph_iris[inx] = gid;
	      if (GRAPH_IRI_ID_DEFAULT == gid)
		out_scope->include_default = true;
	    }
	  out_scope->graph_count = n;
	  out_scope->graph_set_id = vgraph_scope_set_id (out_scope->graph_iris, n);
	  out_scope->is_explicit = true;
	  return GRAPH_OK;
	}
      graph_iri_id_t explicit_iri = vgraph_iri_to_id_ex (graph_arg, qst);

      /* A graph this session built from its own edges answers to the
       * name it was given, but is held under a private id so that two
       * sessions using the same name cannot meet in the snapshot cache.
       * Substituting here is what makes OPTION (graph <x>) and the SQL
       * forms reach it without either knowing it is transient. */
      {
	query_instance_t *qi = (query_instance_t *) qst;
	graph_iri_id_t priv = vgraph_edge_src_private_id (explicit_iri,
	    qi ? qi->qi_client : NULL);
	if (priv)
	  explicit_iri = priv;
      }

      if (explicit_iri == GRAPH_IRI_ID_INVALID)
	{
	  /* A graph the store has never heard of gets the same answer as
	   * one that exists and is empty (quad_store_get_graph() misses,
	   * setup_algo_context() returns GRAPH_ERR_NOT_FOUND) and as one
	   * the caller may not read (vgraph_scope_check_read_perms()
	   * returns GRAPH_ERR_PERMISSION_DENIED, whose text is "Not found"
	   * for exactly this reason).  All three must stay
	   * indistinguishable, or the error tells an unauthorised caller
	   * which graphs exist. */
	  return GRAPH_ERR_NOT_FOUND;
	}

      out_scope->graph_iris = dk_alloc (sizeof (graph_iri_id_t));
      if (!out_scope->graph_iris)
	return GRAPH_ERR_OUT_OF_MEMORY;

      out_scope->graph_iris[0] = explicit_iri;
      out_scope->graph_count = 1;
      out_scope->graph_set_id = explicit_iri;
      out_scope->is_explicit = true;
      out_scope->include_default = (explicit_iri == GRAPH_IRI_ID_DEFAULT);

      return GRAPH_OK;
    }

  /* No graph argument: the default graph.  A SPARQL dataset reaches the
   * BIF as that argument, injected by the compiler from FROM / GRAPH. */
  graph_iri_id_t default_iri = GRAPH_IRI_ID_DEFAULT;

  out_scope->graph_iris = dk_alloc (sizeof (graph_iri_id_t));
  if (!out_scope->graph_iris)
    return GRAPH_ERR_OUT_OF_MEMORY;

  out_scope->graph_iris[0] = default_iri;
  out_scope->graph_count = 1;
  out_scope->graph_set_id = default_iri;
  out_scope->is_explicit = false;
  out_scope->include_default = true;

  return GRAPH_OK;
}

void
vgraph_scope_free (vgraph_resolved_scope_t *scope)
{
  if (!scope)
    return;
  if (scope->graph_iris)
    {
      dk_free (scope->graph_iris, scope->graph_count * sizeof (graph_iri_id_t));
      scope->graph_iris = NULL;
    }
  scope->graph_count = 0;
}

/* ============================================================================
 * QUAD LOADING FROM RDF_QUAD
 * ============================================================================ */

/*
 * SQL query template for loading quads from a specific graph.
 * Uses parameterized query to avoid SQL injection.
 */
static const char *LOAD_GRAPH_SQL = "SELECT S, P, O FROM DB.DBA.RDF_QUAD WHERE G = ?";

static const char *LOAD_ALL_SQL = "SELECT G, S, P, O FROM DB.DBA.RDF_QUAD";

/* Compile-once plan for the fixed-text LOAD_ALL_SQL (no scope, no
 * predicate filter).  Freed at server shutdown, like the ID-to-IRI
 * query below; guarded by g_iri_to_id_compile_mtx. */
static query_t *g_load_all_qr = NULL;

/* The reifier nodes of one graph: the subjects of its rdf:subject and
 * rdf:reifies triples.
 *
 * Excluding the four reification predicates drops the triples that SAY a
 * node is a reifier and leaves the node itself, so any OTHER property of it
 * is still read as an edge.  A reifier typed `a :Transfer` put the class
 * into the graph and took a three-node chain from one component to two.
 *
 * Collected into a sorted array and bisected during the scan rather than
 * expressed as a SQL anti-join: on a 250k-triple graph with 50k reifiers,
 * `S NOT IN (subquery)` cost 168 ms and `NOT EXISTS` 175 ms against a 50 ms
 * baseline, while the query that gathers the same 50k ids runs in 1 ms.
 * The whole cost of the join was per-row re-evaluation. */
typedef struct
{
  graph_iri_id_t *ids;		/* sorted ascending */
  uint64_t count;
  bool overflowed;		/* too many to hold; see below */
} vgraph_reifier_set_t;

/* Beyond this the set is not held and the load proceeds without it, which
 * restores the old behaviour for that graph rather than failing the query.
 * 1M ids is 8 MB; a graph with more reified statements than that is not one
 * whose reifiers are being typed by hand. */
#define VGRAPH_MAX_REIFIERS 1000000

static int
vgraph_iri_id_cmp (const void *a, const void *b)
{
  graph_iri_id_t x = *(const graph_iri_id_t *) a;
  graph_iri_id_t y = *(const graph_iri_id_t *) b;
  return (x < y) ? -1 : ((x > y) ? 1 : 0);
}

static void
vgraph_reifier_set_free (vgraph_reifier_set_t *rs)
{
  if (rs && rs->ids)
    {
      dk_free (rs->ids, -1);
      rs->ids = NULL;
    }
  if (rs)
    {
      rs->count = 0;
      rs->overflowed = false;
    }
}

static bool
vgraph_reifier_set_has (const vgraph_reifier_set_t *rs, graph_iri_id_t id)
{
  uint64_t lo, hi;
  if (!rs || !rs->ids || !rs->count)
    return false;
  lo = 0;
  hi = rs->count;
  while (lo < hi)
    {
      uint64_t mid = lo + (hi - lo) / 2;
      if (rs->ids[mid] < id)
	lo = mid + 1;
      else
	hi = mid;
    }
  return (lo < rs->count && rs->ids[lo] == id);
}

/* Fills rs; leaves it empty when the graph has no reifiers, which is the
 * common case and costs one index probe. */
static void
vgraph_reifier_set_collect (client_connection_t *cli, query_instance_t *qi, graph_iri_id_t graph_iri, vgraph_reifier_set_t *rs)
{
  graph_iri_id_t rsubj = 0, rpred = 0, robj = 0, rreifies = 0;
  char sql[512];
  query_t *qr = NULL;
  local_cursor_t *lc = NULL;
  caddr_t err = NULL;
  uint64_t cap = 0;

  memset (rs, 0, sizeof (*rs));
  if (!cli || !qi)
    return;
  vgraph_reification_vocab_ids (qi, &rsubj, &rpred, &robj, &rreifies);
  if (!rsubj || !rreifies)
    return;

  snprintf (sql, sizeof (sql),
      "SELECT S FROM DB.DBA.RDF_QUAD WHERE G = #i%llu"
      " AND P IN (#i%llu, #i%llu)", (unsigned long long) graph_iri, (unsigned long long) rsubj, (unsigned long long) rreifies);
  qr = sql_compile (sql, cli, &err, SQLC_DEFAULT);
  if (err || !qr)
    {
      if (err)
	dk_free_tree (err);
      return;
    }
  err = qr_rec_exec (qr, cli, &lc, qi, NULL, 0);
  if (err)
    {
      dk_free_tree (err);
      if (lc)
	lc_free (lc);
      qr_free (qr);
      return;
    }

  while (lc && lc_next (lc))
    {
      graph_iri_id_t id = vgraph_iri_to_id (lc_nth_col (lc, 0));
      if (!id)
	continue;
      if (rs->count == cap)
	{
	  uint64_t ncap = cap ? cap * 2 : 1024;
	  graph_iri_id_t *wider;
	  if (ncap > VGRAPH_MAX_REIFIERS)
	    {
	      rs->overflowed = true;
	      break;
	    }
	  wider = (graph_iri_id_t *) dk_alloc (ncap * sizeof (graph_iri_id_t));
	  if (!wider)
	    {
	      rs->overflowed = true;
	      break;
	    }
	  if (rs->ids)
	    {
	      memcpy (wider, rs->ids, (size_t) rs->count * sizeof (graph_iri_id_t));
	      dk_free (rs->ids, -1);
	    }
	  rs->ids = wider;
	  cap = ncap;
	}
      rs->ids[rs->count++] = id;
    }
  if (lc)
    lc_free (lc);
  qr_free (qr);

  if (rs->overflowed)
    {
      vgraph_reifier_set_free (rs);
      return;
    }
  if (rs->count > 1)
    qsort (rs->ids, (size_t) rs->count, sizeof (graph_iri_id_t), vgraph_iri_id_cmp);
}

/* Enforce the size limits while the scan is running.
 *
 * These used to be checked only after the whole graph had been read into
 * memory and snapshotted, so refusing a 120,000-node graph still cost the
 * full scan and its allocations - the limit amplified the load instead of
 * bounding it.  Checking every VGRAPH_LOAD_CHECK_ROWS rows keeps the cost
 * negligible and the overshoot small, and gives the loop somewhere to
 * notice that the query has been cancelled.
 *
 * Returns GRAPH_OK to continue, or the error to abort with. */

static graph_error_t
vgraph_load_check_limits (quad_store_t *store, graph_iri_id_t graph_id, client_connection_t *cli, uint64_t loaded)
{
  uint64_t nodes = 0, quads = 0;
  uint64_t max_nodes = vgraph_max_nodes_limit ();
  uint64_t max_triples = vgraph_max_triples_limit ();

  if (cli && CLI_TERMINATE == cli->cli_terminate_requested)
    {
      vgraph_load_error_set_text ("the query was cancelled");
      return GRAPH_ERR_IO_ERROR;
    }
  if (max_triples && loaded > max_triples)
    return GRAPH_ERR_CAPACITY_EXCEEDED;
  if (!max_nodes)
    return GRAPH_OK;
  if (quad_store_graph_counts (store, graph_id, &nodes, &quads) != GRAPH_OK)
    return GRAPH_OK;
  if (nodes > max_nodes)
    return GRAPH_ERR_CAPACITY_EXCEEDED;
  return GRAPH_OK;
}

graph_error_t
vgraph_load_from_rdf_quad (void *qst,
    quad_store_t *store, const vgraph_resolved_scope_t *scope, const graph_pred_filter_t *pred_filter, uint64_t *out_loaded)
{
  if (!qst || !store)
    return GRAPH_ERR_NULL_PTR;

  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi ? qi->qi_client : NULL;
  /* Never fall back to sqlc_client()/bootstrap_cli here: this scan reads
   * RDF_QUAD directly and must run with the caller's own rights, or the
   * graph-level check in vgraph_resolve_scope() could be sidestepped. */
  if (!cli)
    return GRAPH_ERR_NOT_INITIALIZED;

  caddr_t exec_err = NULL;
  query_t *qr = NULL;
  bool qr_shared = false;	/* static plan - do not qr_free */
  local_cursor_t *lc = NULL;
  uint64_t loaded = 0;
  graph_error_t result = GRAPH_OK;

  /* Build predicate filter SQL clause if needed */
  char pred_clause[1024] = "";
  /* The reifier NODES, which pred_clause cannot exclude: it filters on
   * the predicate, and a reifier's other properties carry their own. */
  vgraph_reifier_set_t reifiers;
  memset (&reifiers, 0, sizeof (reifiers));
  bool exclude_reifiers = false;
  if (pred_filter && pred_filter->count > 0)
    {
      /* Build IN or NOT IN clause for predicates.  Bounded: the buffer is
       * fixed, and an unbounded strcat here was one caller away from a
       * stack overflow. */
      size_t used = 0;
      int n;
      n = snprintf (pred_clause, sizeof (pred_clause), "%s", pred_filter->exclude ? " AND P NOT IN (" : " AND P IN (");
      if (n < 0 || (size_t) n >= sizeof (pred_clause))
	return GRAPH_ERR_INVALID_PARAM;
      used = (size_t) n;
      for (uint32_t i = 0; i < pred_filter->count; i++)
	{
	  n = snprintf (pred_clause + used, sizeof (pred_clause) - used,
	      "%s#i%llu", i > 0 ? "," : "", (unsigned long long) pred_filter->predicates[i]);
	  if (n < 0 || (size_t) n >= sizeof (pred_clause) - used)
	    return GRAPH_ERR_INVALID_PARAM;	/* too many predicates */
	  used += (size_t) n;
	}
      if (used + 2 > sizeof (pred_clause))
	return GRAPH_ERR_INVALID_PARAM;
      pred_clause[used++] = ')';
      pred_clause[used] = '\0';
    }
  else if (qi)
    {
      /* All-predicates load: exclude the RDF reification vocabulary
       * (rdf:subject / rdf:predicate / rdf:object / rdf:reifies).  These
       * triples carry the identity of a reified statement - RDF-star
       * represents the same statement by its reifier IRI - so they are
       * statement metadata, not graph structure.  Without this, every
       * reified statement (W3C reification or an RDF 1.2 << >> term)
       * would add bogus edges from the statement node to the parts of
       * the reified triple.  An explicit predicate filter already pins
       * the load to the requested predicate. */
      graph_iri_id_t rsubj = 0, rpred = 0, robj = 0, rreifies = 0;
      vgraph_reification_vocab_ids (qi, &rsubj, &rpred, &robj, &rreifies);
      if (rsubj && rpred && robj && rreifies)
	{
	  snprintf (pred_clause, sizeof (pred_clause),
	      " AND P NOT IN (#i%llu, #i%llu, #i%llu, #i%llu)",
	      (unsigned long long) rsubj, (unsigned long long) rpred, (unsigned long long) robj, (unsigned long long) rreifies);
	  /* Only an all-predicates load can pick a reifier's other
	   * properties up as edges; an explicit predicate filter has
	   * already pinned the load to what the caller asked for. */
	  exclude_reifiers = true;
	}
    }

  /* Determine loading strategy */
  if (!scope || scope->graph_count == 0)
    {
      /* No scope - this is a performance WARNING case */
      /* We still allow it but log/warn */
      if (!pred_clause[0])
	{
	  /* Fixed text: compile once and share the plan across calls
	   * and connections; the static plan is freed at server
	   * shutdown. */
	  if (!g_load_all_qr)
	    {
	      caddr_t compile_err = NULL;
	      mutex_enter (g_iri_to_id_compile_mtx);
	      if (!g_load_all_qr)
		g_load_all_qr = sql_compile_static (LOAD_ALL_SQL, cli, &compile_err, SQLC_DEFAULT);
	      mutex_leave (g_iri_to_id_compile_mtx);
	      if (compile_err)
		{
		  vgraph_load_error_set (compile_err);
		  dk_free_tree (compile_err);
		}
	    }
	  if (!g_load_all_qr)
	    {
	      result = GRAPH_ERR_IO_ERROR;
	      goto cleanup;
	    }
	  qr = g_load_all_qr;
	  qr_shared = true;
	}
      else
	{
	  char sql[2048];
	  snprintf (sql, sizeof (sql), "%s%s", LOAD_ALL_SQL, pred_clause);
	  qr = sql_compile (sql, cli, &exec_err, SQLC_DEFAULT);
	  if (exec_err)
	    {
	      vgraph_load_error_set (exec_err);
	      result = GRAPH_ERR_IO_ERROR;
	      goto cleanup;
	    }
	}

      exec_err = qr_rec_exec (qr, cli, &lc, qi, NULL, 0);
      if (exec_err)
	{
	  vgraph_load_error_set (exec_err);
	  result = GRAPH_ERR_IO_ERROR;
	  goto cleanup;
	}

      /* Load all quads */
      while (lc_next (lc))
	{
	  caddr_t g_box = lc_nth_col (lc, 0);
	  caddr_t s_box = lc_nth_col (lc, 1);
	  caddr_t p_box = lc_nth_col (lc, 2);
	  caddr_t o_box = lc_nth_col (lc, 3);

	  graph_quad_t quad = {
	    .graph = vgraph_iri_to_id (g_box),
	    .subject = vgraph_node_to_id_ex (s_box, qst),
	    .predicate = vgraph_pred_to_id_ex (p_box, qst),
	    .object = vgraph_node_to_id_ex (o_box, qst)
	  };

	  if (quad_store_add_quad (store, &quad) == GRAPH_OK)
	    {
	      loaded++;
	      if (0 == (loaded % VGRAPH_LOAD_CHECK_ROWS))
		{
		  result = vgraph_load_check_limits (store, quad.graph, cli, loaded);
		  if (result != GRAPH_OK)
		    goto cleanup;
		}
	    }

	  /* Check for iteration errors */
	  if (lc->lc_error)
	    {
	      vgraph_load_error_set (lc->lc_error);
	      result = GRAPH_ERR_IO_ERROR;
	      goto cleanup;
	    }
	}
    }
  else
    {
      /* Scoped loading - bake graph IRI ID into SQL to avoid
       * parameter passing issues with QRP_RAW + box_iri_id. */
      for (uint32_t gi = 0; gi < scope->graph_count; gi++)
	{
	  graph_iri_id_t graph_iri = scope->graph_iris[gi];

	  /* Bake the graph IRI ID into the SQL string to avoid
	   * parameter passing issues with QRP_RAW + box_iri_id.
	   * Use #i prefix for IRI_ID literals in Virtuoso SQL. */
	  char scoped_sql[2048];
	  if (exclude_reifiers)
	    vgraph_reifier_set_collect (cli, qi, graph_iri, &reifiers);
	  snprintf (scoped_sql, sizeof (scoped_sql),
	      "SELECT S, P, O FROM DB.DBA.RDF_QUAD WHERE G = #i%llu%s", (unsigned long long) graph_iri, pred_clause);

	  qr = sql_compile (scoped_sql, cli, &exec_err, SQLC_DEFAULT);
	  if (exec_err)
	    {
	      vgraph_load_error_set (exec_err);
	      result = GRAPH_ERR_IO_ERROR;
	      goto cleanup;
	    }

	  exec_err = qr_rec_exec (qr, cli, &lc, qi, NULL, 0);

	  if (exec_err)
	    {
	      /* Leave both to the cleanup label, which frees the cursor
	       * before the query: lc_free() frees the query instance, and
	       * that still references the query. */
	      vgraph_load_error_set (exec_err);
	      result = GRAPH_ERR_IO_ERROR;
	      goto cleanup;
	    }

	  /* Load triples for this graph */
	  while (lc_next (lc))
	    {
	      caddr_t s_box = lc_nth_col (lc, 0);
	      caddr_t p_box = lc_nth_col (lc, 1);
	      caddr_t o_box = lc_nth_col (lc, 2);

	      graph_quad_t quad = {
		.graph = scope->graph_set_id,
		.subject = vgraph_node_to_id_ex (s_box, qst),
		.predicate = vgraph_pred_to_id_ex (p_box, qst),
		.object = vgraph_node_to_id_ex (o_box, qst)
	      };

	      /* A statement's reifier is metadata about that statement,
	       * not a node of the graph, so none of its triples are
	       * edges.  Bisection over a sorted array; empty for a graph
	       * with no reified statements, which costs nothing. */
	      if (reifiers.count && vgraph_reifier_set_has (&reifiers, quad.subject))
		continue;

	      if (quad_store_add_quad (store, &quad) == GRAPH_OK)
		{
		  loaded++;
		  if (0 == (loaded % VGRAPH_LOAD_CHECK_ROWS))
		    {
		      result = vgraph_load_check_limits (store, scope->graph_set_id, cli, loaded);
		      if (result != GRAPH_OK)
			goto cleanup;
		    }
		}

	      if (lc->lc_error)
		{
		  vgraph_load_error_set (lc->lc_error);
		  result = GRAPH_ERR_IO_ERROR;
		  goto cleanup;
		}
	    }

	  lc_free (lc);
	  lc = NULL;
	  qr_free (qr);
	  qr = NULL;
	}
    }

  /* Commit all loaded data */
  quad_store_commit (store);

cleanup:
  vgraph_reifier_set_free (&reifiers);
  if (lc)
    lc_free (lc);
  if (qr && !qr_shared)
    qr_free (qr);
  if (exec_err)
    dk_free_tree (exec_err);

  if (out_loaded)
    *out_loaded = loaded;
  return result;
}

/* ============================================================================
 * QUAD LOADING FROM A SQL TABLE
 *
 * Measured on 4,000,000 real edges, same machine, same log and checkpoint
 * settings: loading them into a two-column SQL table with the stock
 * vectored CSV loader takes 1.21 us an edge across four connections,
 * against 14.47 us an edge for the same edges through rdf_loader_run.
 * The difference is not that RDF is slow -- the same edges *without* their
 * weights load at 2.77 us a triple, faster per row than the table does.
 * It is that a weighted edge is three rows in RDF and one in a table: the
 * edge, a blank-node reifier, and the weight assertion.
 *
 * So this reads the edges from where they already are, instead of asking
 * a caller to spend 452 seconds turning them into triples first.
 * ============================================================================ */

/* A table name is pasted into SQL text, so it is checked rather than
 * escaped: up to three dot-separated parts, each a plain identifier, and
 * nothing else.  Quoted identifiers, spaces, comment markers and anything
 * that could close the FROM clause are refused outright.  This is the
 * whole injection defence and it is deliberately narrower than what SQL
 * would accept.
 *
 * Not static: the weight-column reader in bif_graph.c interpolates a
 * table and a column name into SQL too, and there must be one copy of
 * this test rather than two that can drift. */
bool
vgraph_table_name_ok (const char *name)
{
  int parts = 1;
  size_t i, len;
  if (!name)
    return false;
  len = strlen (name);
  if (!len || len > 200)
    return false;
  for (i = 0; i < len; i++)
    {
      char c = name[i];
      if (c == '.')
	{
	  /* no empty part, and at most three */
	  if (0 == i || i + 1 == len || name[i - 1] == '.')
	    return false;
	  if (++parts > 3)
	    return false;
	  continue;
	}
      if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '$'))
	return false;
    }
  /* A part may not start with a digit. */
  if (name[0] >= '0' && name[0] <= '9')
    return false;
  for (i = 1; i < len; i++)
    if (name[i - 1] == '.' && name[i] >= '0' && name[i] <= '9')
      return false;
  return true;
}

/* Load edges from `SELECT S, O FROM <table>` into the store under one
 * graph IRI and one predicate.
 *
 * The column values are the node ids.  A caller that puts IRI_IDs there
 * gets a graph indistinguishable from an RDF-loaded one -- same ids, same
 * read-out, same answers -- which is what the equality cases in the suite
 * rely on.  A caller that puts plain integers there gets a graph whose
 * algorithms all work and whose read-out is those integers.
 *
 * Weights are not read here even when the table has a weight column, and
 * that is a decision rather than an omission.  They are read on the first
 * weighted call, by build_weight_lookup_from_table_unsorted() in
 * bif_graph.c, which puts them on the same lifecycle as RDF weights --
 * built lazily, shared between calls, keyed on the cache generation.
 * Collecting them here instead would mean holding one row per edge, 24
 * bytes at 34,185,747 edges, alive across the CSR build on top of
 * everything else the build needs, and doing it again in the reload path
 * that a cache miss takes.  Two places, and the memory at the worst
 * moment, to save a scan that costs a few seconds.
 *
 * Permission: the scan runs on the caller's own connection, exactly as
 * vgraph_load_from_rdf_quad() does and for the same reason.  "May this
 * user read this table" is a question SQL already answers, and running the
 * SELECT under the caller's rights is what asks it.  Never bootstrap_cli.
 */
graph_error_t
vgraph_load_from_table (void *qst,
    quad_store_t *store, const char *table, graph_iri_id_t graph_id, graph_pred_id_t pred_id, uint64_t *out_loaded)
{
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi ? qi->qi_client : NULL;
  caddr_t exec_err = NULL;
  query_t *qr = NULL;
  local_cursor_t *lc = NULL;
  uint64_t loaded = 0;
  graph_error_t result = GRAPH_OK;
  char sql[512];

  if (out_loaded)
    *out_loaded = 0;
  if (!qst || !store || !table)
    return GRAPH_ERR_NULL_PTR;
  if (!cli)
    return GRAPH_ERR_NOT_INITIALIZED;
  if (!vgraph_table_name_ok (table))
    return GRAPH_ERR_INVALID_PARAM;

  snprintf (sql, sizeof (sql), "SELECT S, O FROM %s", table);

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
      caddr_t s_box = lc_nth_col (lc, 0);
      caddr_t o_box = lc_nth_col (lc, 1);
      graph_quad_t quad;

      quad.graph = graph_id;
      quad.subject = vgraph_node_to_id_ex (s_box, qst);
      quad.predicate = pred_id;
      quad.object = vgraph_node_to_id_ex (o_box, qst);

      if (GRAPH_NODE_ID_INVALID == quad.subject || GRAPH_NODE_ID_INVALID == quad.object)
	continue;		/* a NULL endpoint is not an edge */

      if (quad_store_add_quad (store, &quad) == GRAPH_OK)
	{
	  loaded++;
	  if (0 == (loaded % VGRAPH_LOAD_CHECK_ROWS))
	    {
	      result = vgraph_load_check_limits (store, graph_id, cli, loaded);
	      if (result != GRAPH_OK)
		goto cleanup;
	    }
	}
      if (lc->lc_error)
	{
	  vgraph_load_error_set (lc->lc_error);
	  result = GRAPH_ERR_IO_ERROR;
	  goto cleanup;
	}
    }

  quad_store_commit (store);

cleanup:
  if (lc)
    lc_free (lc);
  if (qr)
    qr_free (qr);
  if (exec_err)
    dk_free_tree (exec_err);
  if (out_loaded)
    *out_loaded = loaded;
  return result;
}

/* ============================================================================
 * LOAD QUADS FROM PRE-LOADED VIRTUOSO VECTOR
 *
 * When called from within a SPARQL query via PL wrapper procedures,
 * the BIF cannot reliably open SQL cursors on RDF_QUAD. Instead, the PL
 * wrapper pre-loads the quads using PL cursors and passes them as a
 * Virtuoso vector of 3-element sub-vectors: [[S, P, O], [S, P, O], ...]
 * where each element is an IRI_ID.
 * ============================================================================ */

graph_error_t
vgraph_load_from_vector_ex (quad_store_t *store, graph_iri_id_t graph_id, void *quad_vector, void *qst, uint64_t *out_loaded)
{
  if (!store || !quad_vector)
    return GRAPH_ERR_NULL_PTR;

  int tag = DV_TYPE_OF (quad_vector);
  if (tag != DV_ARRAY_OF_POINTER && tag != DV_LIST_OF_POINTER)
    return GRAPH_ERR_INVALID_PARAM;

  uint64_t n = BOX_ELEMENTS (quad_vector);
  uint64_t loaded = 0;
  caddr_t *vec = (caddr_t *) quad_vector;

  for (uint64_t i = 0; i < n; i++)
    {
      caddr_t row = vec[i];
      if (!row)
	continue;
      int row_tag = DV_TYPE_OF (row);
      if (row_tag != DV_ARRAY_OF_POINTER && row_tag != DV_LIST_OF_POINTER)
	continue;
      if (BOX_ELEMENTS (row) < 3)
	continue;

      caddr_t *cols = (caddr_t *) row;
      graph_quad_t quad = {
	.graph = graph_id,
	.subject = vgraph_node_to_id_ex (cols[0], qst),
	.predicate = vgraph_pred_to_id_ex (cols[1], qst),
	.object = vgraph_node_to_id_ex (cols[2], qst)
      };

      if (quad_store_add_quad (store, &quad) == GRAPH_OK)
	{
	  loaded++;
	}
    }

  quad_store_commit (store);

  if (out_loaded)
    *out_loaded = loaded;
  return GRAPH_OK;
}

/* Legacy wrapper without qst */
graph_error_t
vgraph_load_from_vector (quad_store_t *store, graph_iri_id_t graph_id, void *quad_vector, uint64_t *out_loaded)
{
  return vgraph_load_from_vector_ex (store, graph_id, quad_vector, NULL, out_loaded);
}
