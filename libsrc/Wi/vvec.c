/*
 *  vvec.c
 *
 *  $Id$
 *
 *  Vector column and vector-index SQL support functions.
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
#include "sqlnode.h"
#include "sqlfn.h"
#include "sqlbif.h"
#include "sqltype.h"
#include "wi.h"
#include "wifn.h"
#include "sqlpar.h"
#include "sqlo.h"
#include "sqlparext.h"
#include "recovery.h"
#include "log.h"
#include "security.h"
#include <openssl/md5.h>
#include "util/md5.h"

#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "../vvec/vvec_simd.h"      /* Rule 6: vector algorithm code lives under libsrc/vvec/ */
#include "../vvec/vvec_hnsw.h"      /* in-memory parallel HNSW builder for bulk rebuild */


#define VVEC_MAGIC 0x56564543L
#define VVEC_VERSION 1
#define VVEC_ROLE_META 1
#define VVEC_ROLE_NODE 2
#define VVEC_ROLE_OVERFLOW 3
#define VVEC_ROLE_PACKED 4	/* Phase 4: multiple nodes per DPF_VEC page */
#define VVEC_MAX_LAYERS 16
#define VVEC_METRIC_COSINE 1
#define VVEC_METRIC_L2 2
#define VVEC_METRIC_L1 3
#define VVEC_REDUCE_NONE 0
#define VVEC_REDUCE_TRUNCATE 1
#define VVEC_NODE_DELETED 1
#define VVEC_NODE_OVERFLOW 2
#define VVEC_OVERFLOW_DELETED 1
#define VVEC_DISTANCE_INF 1e30f

/* Phase 4: packed durable page format.
 *
 * A vvec_node_ref_t encodes a (page_dp, slot) pair in 32 bits so that
 * neighbor links stay 4 bytes (same as the legacy dp_addr_t).  The
 * encoding uses the low VVEC_NREF_SLOT_BITS bits for the slot index
 * within the page and the remaining bits for the page dp.
 *
 * Legacy one-node-per-page pages (role=VVEC_ROLE_NODE) always have
 * slot=0, so a vvec_node_ref_t for a legacy node is simply
 * (page_dp << VVEC_NREF_SLOT_BITS).  Packed pages (role=VVEC_ROLE_PACKED)
 * use slots 0..VVEC_NREF_MAX_SLOTS-1. */
#define VVEC_NREF_SLOT_BITS 3
#define VVEC_NREF_MAX_SLOTS (1 << VVEC_NREF_SLOT_BITS)
#define VVEC_NREF_SLOT_MASK (VVEC_NREF_MAX_SLOTS - 1)
#define VVEC_NREF_PAGE(nref)  ((dp_addr_t)((nref) >> VVEC_NREF_SLOT_BITS))
#define VVEC_NREF_SLOT(nref)  ((int)((nref) & VVEC_NREF_SLOT_MASK))
#define VVEC_NREF_MAKE(page, slot)  (((uint32)(page) << VVEC_NREF_SLOT_BITS) | ((uint32)(slot) & VVEC_NREF_SLOT_MASK))
typedef uint32_t vvec_node_ref_t;

#define VVEC_OPT_VECTOR "vector"
#define VVEC_OPT_MODEL "m"
#define VVEC_OPT_MODEL_ID "mid"
#define VVEC_OPT_DIMENSIONS "d"
#define VVEC_OPT_NATIVE_DIMENSIONS "nd"
#define VVEC_OPT_REDUCE "rd"
#define VVEC_OPT_DISTANCE "mt"
#define VVEC_OPT_HNSW_M "hm"
#define VVEC_OPT_EF_CONSTR "ef"
#define VVEC_OPT_HIDDEN_TABLE "ht"
#define VVEC_OPT_STATE "st"
#define VVEC_OPT_SOURCE_COLUMN "sc"
#define VVEC_OPT_PK_COLUMN "pk"
#define VVEC_OPT_REBUILD "rb"
#define VVEC_OPT_SOURCE_KIND "sk"
#define VVEC_OPT_BUILD "bd"

/* Where an index's embedding vectors come from.  TEXT (default) = the model
 * path: the source column holds text, fed to an ONNX model (or in-core test
 * model) to produce the embedding.  VECTOR = the "bring your own vectors"
 * passthrough path: the source column already holds precomputed float vectors
 * and there is no model (model_id = 0).  Selected by the DDL option
 * source_kind='text'|'vector' and gated behind the __vvec_passthrough_column
 * registry flag. */
#define VVEC_SOURCE_TEXT   0
#define VVEC_SOURCE_VECTOR 1
#define VVEC_SOURCE_RDF_OBJ 2	/* index on DB.DBA.RDF_OBJ keyed by RO_ID, text resolved from RO_VAL/RO_LONG */

/* Which __VEC_INDEX_REBUILD implementation an index uses. UNSET falls through to
 * the env fallback and then the built-in default (auto). AUTO chooses FAST when
 * the embedding count is at least VVEC_REBUILD_AUTO_MIN, else REPLAY.
 *
 * AUTO_MIN is the crossover where the fast bulk build becomes worthwhile: below
 * it, replay is sub-second and the fast path's arena setup overhead isn't worth
 * it.  At 10K 384-d vectors the fast path's heap overhead is ~33 MB — trivial.
 * Stage B benchmarking (vvec-production-readiness/bench/REBUILD_RESULTS.md)
 * measured fast at 3.1x faster than replay at 100K (11.8s vs 36.4s) with
 * recall 100 vs 76, confirming the crossover is well below 100K.  The upper
 * bound on fast-path memory is enforced by VVEC_FAST_REBUILD_MAX_BYTES (the
 * memory guard), not by AUTO_MIN — so AUTO_MIN can stay low without risk.
 *
 * MAX_AUTO_THREADS caps the auto thread count to avoid monopolizing all cores.
 * At 8 threads on a 10-core machine, Stage B measured 8467 nodes/s at 100K;
 * the 2 spare cores keep the server responsive.  On lower-core machines,
 * vvec_default_build_threads returns the online CPU count (capped at this). */
#define VVEC_REBUILD_UNSET  0
#define VVEC_REBUILD_REPLAY 1
#define VVEC_REBUILD_FAST   2
#define VVEC_REBUILD_AUTO   3
#define VVEC_REBUILD_AUTO_MIN 10000
#define VVEC_REBUILD_MAX_AUTO_THREADS 8
/* Ceiling on an operator's __vec_rebuild_threads: the builder uses one pthread
   per thread, so an absurd value would only oversubscribe the machine. */
#define VVEC_REBUILD_MAX_THREADS 256
/* Replay rebuild commits every this many inserts, bounding the resident dirty
 * DPF_VEC buffer set so replay scales linearly instead of thrashing once the
 * uncommitted set outruns the buffer pool.  See
 * vvec-production-readiness/bench/500K_report.md. */
/* A new node contributes a full PAGE_SZ LOG_VEC_PAGE image.  Keep a replay
 * rebuild chunk comfortably below the default 50 MB transaction log-image
 * limit, leaving room for backlinks and root-page deltas. */
#define VVEC_REPLAY_CHUNK_SIZE 4000
/* Upper bound on the fast bulk builder's heap consumption.  The builder holds
 * all vectors once in the caller's arena (borrowed by the HNSW builder), plus
 * per-node magnitudes, levels, row pointers, mutexes, and adjacency lists.
 * Approximate per-node cost: dim * sizeof(float) + ~224 bytes overhead.
 * If the estimated footprint exceeds this cap, 'auto' falls back to replay;
 * an explicit 'fast' proceeds but logs a warning.  Configurable at runtime with
 * registry_set ('__vec_fast_rebuild_max_bytes', 'N'), or before start-up with the
 * VVEC_FAST_REBUILD_MAX_BYTES env var (bytes).  Default 2 GB — allows ~1.2M
 * 384-d vectors while protecting smaller servers from OOM. */
#define VVEC_FAST_REBUILD_MAX_BYTES_DEFAULT (2L * 1024 * 1024 * 1024)
#define VVEC_REQUIRE_ANN_CLI_VAR "__sqlo_vvec_require_ann"

/* Filter/rerank mode selection for a similarity predicate that co-exists with
 * another filter on the same table (vision Phase 6.2/6.3).  A per-connection
 * override of the optimizer's automatic leading-ANN-vs-filter choice:
 *   AUTO (0)   cost-based (default): leading ANN unless another selective,
 *              index-drivable predicate makes filter-first cheaper;
 *   FILTER (1) force filter/rerank: never take the leading ANN path, so the
 *              plan filters first and reranks the survivors by scalar row
 *              similarity -- returns the complete result set, not a top-k slice;
 *   ANN (2)    force leading ANN regardless of other predicates. */
#define VVEC_FILTER_MODE_CLI_VAR "__sqlo_vvec_filter_mode"
/* VVEC_FILTER_MODE_{AUTO,FILTER,ANN} are declared in wifn.h (shared with the
 * optimizer in sqldf.c / sqloby.c). */

#define VVEC_STATE_CREATED "CREATED"
#define VVEC_STATE_READY_FOR_INTERNAL_LOAD "READY_FOR_INTERNAL_LOAD"
#define VVEC_STATE_READY "READY"

#define VVEC_META_MAGIC (DP_DATA + 0)
#define VVEC_META_ROLE (DP_DATA + 4)
#define VVEC_META_VERSION (DP_DATA + 8)
#define VVEC_META_DIM (DP_DATA + 12)
#define VVEC_META_METRIC (DP_DATA + 16)
#define VVEC_META_HNSW_M (DP_DATA + 20)
#define VVEC_META_EF_CONSTR (DP_DATA + 24)
#define VVEC_META_MODEL_ID (DP_DATA + 28)
#define VVEC_META_ENTRY_DP (DP_DATA + 32)
#define VVEC_META_NODE_HEAD (DP_DATA + 36)
#define VVEC_META_MAX_LAYER (DP_DATA + 40)
#define VVEC_META_TOTAL_NODES (DP_DATA + 44)
#define VVEC_META_ACTIVE_NODES (DP_DATA + 52)
#define VVEC_META_DELETED_NODES (DP_DATA + 60)
#define VVEC_META_INSERT_COUNT (DP_DATA + 68)
#define VVEC_META_SEARCH_COUNT (DP_DATA + 76)
#define VVEC_META_BYTES_WRITTEN (DP_DATA + 84)
#define VVEC_META_INSERT_USEC (DP_DATA + 92)
#define VVEC_META_SEARCH_USEC (DP_DATA + 100)
#define VVEC_META_LAYER0_VISITS (DP_DATA + 108)
#define VVEC_META_LAYER0_HITS (DP_DATA + 116)
#define VVEC_META_OVERFLOW_PAGES (DP_DATA + 124)
#define VVEC_META_DELETED_OVERFLOW_PAGES (DP_DATA + 132)
/* Durability epoch.  Incremented on every graph mutation and mirrored, in the
   mutating transaction, into DB.DBA.VEC_INDEX_EPOCH.  The root page reaches disk
   only at checkpoint, whereas the catalog row is logged, so comparing the two at
   open time detects a graph that a crash left behind the data (or that a
   rollback left ahead of it).  See vvec_epoch_reconcile ().  */
#define VVEC_META_EPOCH (DP_DATA + 140)

#define VVEC_NODE_MAGIC (DP_DATA + 0)
#define VVEC_NODE_ROLE (DP_DATA + 4)
#define VVEC_NODE_VERSION (DP_DATA + 8)
#define VVEC_NODE_FLAGS (DP_DATA + 12)
/* Held the tree's root dp, which nothing ever read -- DP_KEY_ID already says
   which key owns the page.  Left reserved so existing graphs keep their layout. */
#define VVEC_NODE_UNUSED (DP_DATA + 16)
#define VVEC_NODE_NEXT_DP (DP_DATA + 20)
#define VVEC_NODE_MAX_LAYER (DP_DATA + 24)
#define VVEC_NODE_DIM (DP_DATA + 28)
#define VVEC_NODE_METRIC (DP_DATA + 32)
#define VVEC_NODE_HNSW_M (DP_DATA + 36)
#define VVEC_NODE_MAGNITUDE (DP_DATA + 40)
#define VVEC_NODE_D_ID (DP_DATA + 44)
#define VVEC_NODE_COUNTS (DP_DATA + 52)

#define VVEC_NODE_OVERFLOW_HEAD_OFF 0
#define VVEC_NODE_OVERFLOW_BYTES_OFF 4
#define VVEC_NODE_OVERFLOW_REF_BYTES 8

#define VVEC_OV_MAGIC (DP_DATA + 0)
#define VVEC_OV_ROLE (DP_DATA + 4)
#define VVEC_OV_VERSION (DP_DATA + 8)
#define VVEC_OV_FLAGS (DP_DATA + 12)
#define VVEC_OV_UNUSED (DP_DATA + 16)	/* see VVEC_NODE_UNUSED */
#define VVEC_OV_NEXT_DP (DP_DATA + 20)
#define VVEC_OV_BYTES (DP_DATA + 24)
#define VVEC_OV_TOTAL_BYTES (DP_DATA + 28)
#define VVEC_OV_DATA (DP_DATA + 32)

/* Phase 4: packed page format. See comment block above for layout. */
#define VVEC_PK_MAGIC		(DP_DATA + 0)
#define VVEC_PK_ROLE		(DP_DATA + 4)
#define VVEC_PK_VERSION		(DP_DATA + 8)
#define VVEC_PK_UNUSED		(DP_DATA + 12)	/* see VVEC_NODE_UNUSED */
#define VVEC_PK_NODE_COUNT	(DP_DATA + 16)
#define VVEC_PK_NEXT_DP		(DP_DATA + 20)
#define VVEC_PK_HEADER_BYTES	24
#define VVEC_PK_DIR_BASE	(DP_DATA + VVEC_PK_HEADER_BYTES)
#define VVEC_PK_DIR_ENTRY_BYTES	4
#define VVEC_PK_DATA_BASE	(DP_DATA + VVEC_PK_HEADER_BYTES + (VVEC_NREF_MAX_SLOTS * VVEC_PK_DIR_ENTRY_BYTES))
#define VVEC_PK_DATA_USABLE	(PAGE_SZ - VVEC_PK_DATA_BASE)
#define VVEC_CN_MAX_LAYER	0
#define VVEC_CN_FLAGS		1
#define VVEC_CN_DIM		2
#define VVEC_CN_MAGNITUDE	4
#define VVEC_CN_D_ID		8
#define VVEC_CN_N_LAYERS	16
#define VVEC_CN_COUNTS_BASE	17
#define VVEC_CN_FIXED_BYTES	17


struct vvec_arena_s;            /* perf phase 2: in-memory float32 vector arena */

typedef struct vvec_meta_s
{
  dbe_key_t *vm_key;
  index_tree_t *vm_it;
  char *vm_hidden_table;
  int vm_model_id;
  int vm_dimension;
  int vm_native_dimension;
  int vm_reduce;
  int vm_metric;
  int vm_hnsw_m;
  int vm_ef_construction;
  int vm_rebuild;    /* VVEC_REBUILD_* : the index's stored rebuild-method default */
  int vm_source_kind; /* VVEC_SOURCE_TEXT (model path) or VVEC_SOURCE_VECTOR (passthrough) */
  char *vm_state;
  /* perf phase 2: the compute-ready vector arena for this index, or NULL. Set ONLY
   * on the writer-locked build/insert path; left NULL for concurrent external
   * searches, which keeps every arena access single-threaded (see the arena block
   * below). */
  struct vvec_arena_s *vm_arena;
} vvec_meta_t;

/* Retire a graph node whose embedding row is gone.  Defined late, after
   vvec_mark_node_deleted_1; see the comment there.  */
static void vvec_reap_orphan_node (query_instance_t * qi, vvec_meta_t * meta, vvec_node_ref_t nref, caddr_t row_id);


typedef struct vvec_candidate_s
{
  vvec_node_ref_t vc_dp;
  float vc_distance;
} vvec_candidate_t;

typedef struct vvec_cand_list_s
{
  vvec_candidate_t *vcl_items;
  int vcl_fill;
  int vcl_cap;
} vvec_cand_list_t;

typedef struct vvec_search_metrics_s
{
  int vsm_layer0_visits;
  int vsm_layer0_hits;
} vvec_search_metrics_t;


key_id_t ddl_key_name_to_id (query_instance_t * qi, char *name, char *qual);
static caddr_t vvec_insert_embedding_impl (query_instance_t * qi, const char *func_name, char * index_name, caddr_t row_id, caddr_t embedding);
static caddr_t vvec_embed_and_insert_impl (query_instance_t * qi, const char *func_name, char * index_name, caddr_t row_id, char * text_value);
static caddr_t vvec_embed_text_for_model (query_instance_t * qi, const char *func_name, char * index_name, vvec_meta_t * meta, char * text_value);
static int vvec_key_ready (dbe_key_t * key);
static caddr_t vvec_rebuild_impl (query_instance_t * qi, const char *func_name, char * index_name, int method_override, int threads_override);

static long vvec_query_text_vector_calls = 0;
static dk_mutex_t * vvec_query_text_vector_mtx = NULL;
static query_instance_t * vvec_query_text_vector_qi = NULL;
static caddr_t vvec_query_text_vector_index = NULL;
static caddr_t vvec_query_text_vector_text = NULL;
static int vvec_query_text_vector_model_id = 0;
static caddr_t vvec_query_text_vector_embedding = NULL;


static void
vvec_float_set (db_buf_t place, float f)
{
  FLOAT_TO_EXT (place, &f);
}


static float
vvec_float_ref (db_buf_t place)
{
  float f;
  EXT_TO_FLOAT (&f, place);
  return f;
}


static const char *
vvec_map_opt_name (const char *name)
{
  if (!stricmp (name, "m") || !stricmp (name, "model"))
    return VVEC_OPT_MODEL;
  if (!stricmp (name, "d") || !stricmp (name, "dimensions") || !stricmp (name, "dimension"))
    return VVEC_OPT_DIMENSIONS;
  if (!stricmp (name, "rd") || !stricmp (name, "reduce") || !stricmp (name, "dim_reduce") || !stricmp (name, "reduction"))
    return VVEC_OPT_REDUCE;
  if (!stricmp (name, "mt") || !stricmp (name, "distance_metric") || !stricmp (name, "metric"))
    return VVEC_OPT_DISTANCE;
  if (!stricmp (name, "hm") || !stricmp (name, "hnsw_m"))
    return VVEC_OPT_HNSW_M;
  if (!stricmp (name, "ef") || !stricmp (name, "ef_construction"))
    return VVEC_OPT_EF_CONSTR;
  if (!stricmp (name, "ht") || !stricmp (name, "hidden_table"))
    return VVEC_OPT_HIDDEN_TABLE;
  if (!stricmp (name, "st") || !stricmp (name, "state"))
    return VVEC_OPT_STATE;
  if (!stricmp (name, "mid") || !stricmp (name, "model_id"))
    return VVEC_OPT_MODEL_ID;
  if (!stricmp (name, "sc") || !stricmp (name, "source_column"))
    return VVEC_OPT_SOURCE_COLUMN;
  if (!stricmp (name, "pk") || !stricmp (name, "pk_column") || !stricmp (name, "primary_key_column"))
    return VVEC_OPT_PK_COLUMN;
  if (!stricmp (name, "rb") || !stricmp (name, "rebuild") || !stricmp (name, "rebuild_method"))
    return VVEC_OPT_REBUILD;
  if (!stricmp (name, "sk") || !stricmp (name, "source_kind"))
    return VVEC_OPT_SOURCE_KIND;
  if (!stricmp (name, "bd") || !stricmp (name, "build") || !stricmp (name, "build_method"))
    return VVEC_OPT_BUILD;
  return name;
}


int
vvec_is_string_box (caddr_t box)
{
  if (!box)
    return 0;
  return DV_STRINGP (box) || DV_WIDESTRINGP (box) || DV_C_STRING == DV_TYPE_OF (box) || DV_SYMBOL == DV_TYPE_OF (box);
}

static int
vvec_source_col_is_string_compatible (dbe_column_t * col)
{
  dtp_t dtp;
  if (!col)
    return 0;
  dtp = col->col_sqt.sqt_dtp;
  if (IS_STRING_DTP (dtp) || DV_WIDE == dtp || DV_LONG_STRING == dtp || DV_LONG_WIDE == dtp || DV_ANY == dtp)
    return 1;
  if (DV_BLOB == dtp)
    {
      sql_class_t * scl = col->col_sqt.sqt_class;
      if (scl && scl->scl_name && !strcmp (scl->scl_name, "DB.DBA.__ANY"))
	return 0;
      return 1;
    }
  if (DV_BLOB_WIDE == dtp)
    return 1;
  return 0;
}

/* A source column for source_kind='vector' (precomputed passthrough) must be
 * able to hold a boxed vector value or its serialized bytes: ANY (a native
 * DV_ARRAY_OF_FLOAT / number vector), LONG ANY (DV_BLOB with the __ANY class),
 * or (LONG) VARBINARY.  A plain character/wide column is rejected -- it is
 * almost certainly a mistake and this gives a clearer error at CREATE than a
 * per-row VEC30 at drain time. */
static int
vvec_source_col_is_vector_compatible (dbe_column_t * col)
{
  dtp_t dtp;
  if (!col)
    return 0;
  dtp = col->col_sqt.sqt_dtp;
  if (DV_ANY == dtp)
    return 1;
  if (DV_BIN == dtp || DV_BLOB_BIN == dtp)          /* (long) varbinary */
    return 1;
  if (DV_BLOB == dtp)                                /* LONG ANY == DV_BLOB + __ANY class */
    {
      sql_class_t * scl = col->col_sqt.sqt_class;
      if (scl && scl->scl_name && !strcmp (scl->scl_name, "DB.DBA.__ANY"))
        return 1;
      return 0;                                      /* plain long varchar: reject */
    }
  return 0;
}

static int
vvec_source_col_needs_pk_key (dbe_column_t * col)
{
  dtp_t dtp;
  if (!col)
    return 0;
  dtp = col->col_sqt.sqt_dtp;
  return DV_BLOB == dtp || DV_BLOB_WIDE == dtp;
}


int
vvec_source_column_needs_pk_key (query_instance_t * qi, caddr_t table, caddr_t source_col_name)
{
  dbe_table_t * tb = qi_name_to_table (qi, table);
  dbe_column_t * source_col;
  if (!tb || !vvec_is_string_box (source_col_name))
    return 0;
  source_col = tb_name_to_column (tb, (char *) source_col_name);
  return vvec_source_col_needs_pk_key (source_col);
}

static int
vvec_tb_is_rdf_obj (dbe_table_t * tb)
{
  return tb && tb->tb_name && 0 == stricmp (tb->tb_name, "DB.DBA.RDF_OBJ");
}

static int
vvec_opt_slot_is (caddr_t slot, ptrlong opt)
{
  if (!slot)
    return 0;
  if (!IS_BOX_POINTER (slot))
    return (ptrlong) slot == opt;
  switch (DV_TYPE_OF (slot))
    {
    case DV_SHORT_INT:
    case DV_LONG_INT:
    case DV_INT64:
    case DV_NUMERIC:
      return (ptrlong) unbox (slot) == opt;
    default:
      return 0;
    }
}


caddr_t *
vvec_vector_opts (caddr_t * opts)
{
  int inx, len;
  if (!opts || DV_ARRAY_OF_POINTER != DV_TYPE_OF (opts))
    return NULL;
  len = BOX_ELEMENTS (opts);
  for (inx = 0; inx < len - 1; inx++)
    {
      if (vvec_opt_slot_is (opts[inx], OPT_VECTOR))
	return (caddr_t *) opts[inx + 1];
    }
  return NULL;
}


static int
vvec_parse_int_value (caddr_t val, int *ret)
{
  char *end = NULL;
  long parsed;
  if (!val || !ret)
    return 0;
  if (!IS_BOX_POINTER (val))
    {
      *ret = (int) (ptrlong) val;
      return 1;
    }
  switch (DV_TYPE_OF (val))
    {
    case DV_SHORT_INT:
    case DV_LONG_INT:
    case DV_INT64:
    case DV_NUMERIC:
      *ret = (int) unbox (val);
      return 1;
    case DV_SINGLE_FLOAT:
      *ret = (int) unbox_float (val);
      return 1;
    case DV_DOUBLE_FLOAT:
      *ret = (int) unbox_double (val);
      return 1;
    default:
      break;
    }
  if (!vvec_is_string_box (val))
    return 0;
  parsed = strtol ((char *) val, &end, 10);
  if (!end || end == (char *) val || *end)
    return 0;
  *ret = (int) parsed;
  return 1;
}


static int
vvec_opt_int_value (caddr_t * opts, const char *name, int dflt, int *ret)
{
  caddr_t val = vvec_opt_value (opts, name);
  if (!val)
    {
      *ret = dflt;
      return 1;
    }
  return vvec_parse_int_value (val, ret);
}


caddr_t
vvec_opt_value (caddr_t * opts, const char *name)
{
  caddr_t * v_opts = vvec_vector_opts (opts);
  const char * short_name = vvec_map_opt_name (name);
  int inx, len;
  if (!v_opts || DV_ARRAY_OF_POINTER != DV_TYPE_OF (v_opts))
    return NULL;
  len = (int) BOX_ELEMENTS (v_opts);
  for (inx = 0; inx < len - 1; inx += 2)
    {
      if (vvec_is_string_box (v_opts[inx]))
	{
	  if (!stricmp (vvec_map_opt_name ((char *) v_opts[inx]), short_name))
	    return v_opts[inx + 1];
	}
    }
  return NULL;
}

int
vvec_parse_metric (const char *metric)
{
  if (!metric || !stricmp (metric, "cosine"))
    return VVEC_METRIC_COSINE;
  if (!stricmp (metric, "euclidean") || !stricmp (metric, "l2"))
    return VVEC_METRIC_L2;
  if (!stricmp (metric, "manhattan") || !stricmp (metric, "l1"))
    return VVEC_METRIC_L1;
  return 0;
}


static const char *
vvec_metric_name (int metric)
{
  switch (metric)
    {
    case VVEC_METRIC_COSINE:
      return "cosine";
    case VVEC_METRIC_L2:
      return "euclidean";
    case VVEC_METRIC_L1:
      return "manhattan";
    default:
      return "unknown";
  }
}


static int
vvec_parse_reduce (caddr_t reduce_box, int *reduce_ret)
{
  if (!reduce_ret)
    return 0;
  if (!reduce_box)
    {
      *reduce_ret = VVEC_REDUCE_NONE;
      return 1;
    }
  if (!vvec_is_string_box (reduce_box))
    return 0;
  if (!stricmp ((char *) reduce_box, "none"))
    {
      *reduce_ret = VVEC_REDUCE_NONE;
      return 1;
    }
  if (!stricmp ((char *) reduce_box, "truncate"))
    {
      *reduce_ret = VVEC_REDUCE_TRUNCATE;
      return 1;
    }
  return 0;
}


/* Map a rebuild-method option value to its VVEC_REBUILD_* code.  NULL/empty -> UNSET.
   Returns -1 for an unrecognised non-empty value so callers can reject it. */
static int
vvec_parse_rebuild (caddr_t v)
{
  const char *s;
  if (!vvec_is_string_box (v))
    return VVEC_REBUILD_UNSET;
  s = (const char *) v;
  if (!s[0])
    return VVEC_REBUILD_UNSET;
  if (!stricmp (s, "replay") || !stricmp (s, "insert") || !stricmp (s, "incremental"))
    return VVEC_REBUILD_REPLAY;
  if (!stricmp (s, "fast") || !stricmp (s, "bulk"))
    return VVEC_REBUILD_FAST;
  if (!stricmp (s, "auto"))
    return VVEC_REBUILD_AUTO;
  return -1;
}


static const char *
vvec_reduce_name (int reduce)
{
  switch (reduce)
    {
    case VVEC_REDUCE_TRUNCATE:
      return "truncate";
    case VVEC_REDUCE_NONE:
    default:
      return "none";
    }
}


static int
vvec_arg_is_db_null (caddr_t arg)
{
  return IS_BOX_POINTER (arg) && DV_DB_NULL == DV_TYPE_OF (arg);
}


static int
vvec_metric_from_arg (caddr_t metric_arg, int dflt_metric, const char *func_name)
{
  dtp_t dtp;
  int metric;
  if (!metric_arg || vvec_arg_is_db_null (metric_arg))
    return dflt_metric;
  if (!IS_BOX_POINTER (metric_arg))
    sqlr_new_error ("22023", "VEC43", "%s metric must be a string value.", func_name);
  dtp = DV_TYPE_OF (metric_arg);
  if (!(DV_STRINGP (metric_arg) || DV_C_STRING == dtp || DV_SYMBOL == dtp || DV_UNAME == dtp))
    sqlr_new_error ("22023", "VEC43", "%s metric must be a string value.", func_name);
  metric = vvec_parse_metric ((char *) metric_arg);
  if (!metric)
    sqlr_new_error ("22023", "VEC43", "Unsupported vector metric %.300s in %s.", (char *) metric_arg, func_name);
  return metric;
}


/* Pick the HNSW layer for a node, as a pure function of its d_id.
 *
 * This used to draw on rand (), seeded from time (NULL) in vvec_init (), which
 * made the graph different on every build of the same corpus.  That was
 * tolerable while the graph was an internal detail, but it is not any more:
 *
 *   - Recovery re-inserts the nodes a crash dropped (vvec_epoch_reconcile).
 *     With a clock-seeded draw the repaired graph differs from the one that was
 *     lost, so a restored database answers differently from the original.
 *   - SIMILARITY and DISTANCE are selectable output columns now, so that
 *     difference is visible to users rather than buried.  The per-row score is
 *     graph-independent -- it is the true cosine against the stored embedding --
 *     but which rows an approximate search returns, and in what order, is not.
 *
 * The distribution is unchanged: still geometric with p = 1/4 per level, still
 * capped at VVEC_MAX_LAYERS.  Only the source of the bits changes.  Trailing
 * zero pairs of a well-mixed value are geometrically distributed, which is
 * exactly what the old "0 == (rand () & 3)" loop was counting; 15 climbs
 * consume 30 bits of the 64 available, so the supply cannot run out.
 *
 * The in-memory bulk builder was already deterministic -- vvec_hnsw.h seeds its
 * own generator from the constant 0x9e3779b9 -- so this brings the incremental
 * path into line with it rather than inventing a new policy. */
static int
vvec_layer_for_d_id (int64 d_id)
{
  uint64 x = (uint64) d_id + 0x9e3779b97f4a7c15ULL;
  int layer = 0;
  /* splitmix64 finalizer: cheap, and avalanches adjacent ids apart so that
     consecutively inserted rows do not land on correlated layers. */
  x ^= x >> 30;
  x *= 0xbf58476d1ce4e5b9ULL;
  x ^= x >> 27;
  x *= 0x94d049bb133111ebULL;
  x ^= x >> 31;
  while (layer + 1 < VVEC_MAX_LAYERS && 0 == (x & 3))
    {
      layer++;
      x >>= 2;
    }
  return layer;
}


static int
vvec_node_layer_capacity (int hnsw_m, int layer)
{
  return layer ? hnsw_m : (2 * hnsw_m);
}


static int
vvec_node_layer_base (int hnsw_m, int layer)
{
  if (0 == layer)
    return 0;
  return (2 * hnsw_m) + ((layer - 1) * hnsw_m);
}


static int
vvec_node_total_slots (int hnsw_m)
{
  return (VVEC_MAX_LAYERS + 1) * hnsw_m;
}


static int
vvec_node_vector_offset (int hnsw_m)
{
  return VVEC_NODE_COUNTS + (VVEC_MAX_LAYERS * sizeof (int32)) + (vvec_node_total_slots (hnsw_m) * sizeof (dp_addr_t));
}


static int
vvec_max_inline_dimension (int hnsw_m)
{
  int bytes = PAGE_SZ - vvec_node_vector_offset (hnsw_m);
  if (bytes <= 0)
    return 0;
  return bytes / sizeof (float);
}


static int
vvec_overflow_payload_capacity (void)
{
  return PAGE_SZ - VVEC_OV_DATA;
}


static int
vvec_node_can_hold_overflow_ref (int hnsw_m)
{
  return PAGE_SZ - vvec_node_vector_offset (hnsw_m) >= VVEC_NODE_OVERFLOW_REF_BYTES;
}


#define VVEC_DIM_FITS_INLINE(m, dim) ((dim) <= vvec_max_inline_dimension (m))
#define VVEC_MAX_HNSW_M (PAGE_SZ / (int) ((VVEC_MAX_LAYERS + 1) * sizeof (dp_addr_t)))
/* hnsw_m is bounded first: a large one wraps the int slot arithmetic and seems to fit */
#define VVEC_NODE_FITS_PAGE(m, dim) \
  ((m) > 0 && (m) <= VVEC_MAX_HNSW_M && (VVEC_DIM_FITS_INLINE (m, dim) || vvec_node_can_hold_overflow_ref (m)))


static void
vvec_meta_set_i32 (buffer_desc_t * buf, int off, int32 v)
{
  LONG_SET (buf->bd_buffer + off, v);
}


static int32
vvec_meta_ref_i32 (buffer_desc_t * buf, int off)
{
  return LONG_REF (buf->bd_buffer + off);
}


static void
vvec_meta_set_i64 (buffer_desc_t * buf, int off, int64 v)
{
  INT64_SET (buf->bd_buffer + off, v);
}


static int64
vvec_meta_ref_i64 (buffer_desc_t * buf, int off)
{
  return INT64_REF (buf->bd_buffer + off);
}


static void
vvec_meta_inc_i64 (buffer_desc_t * buf, int off, int64 delta)
{
  vvec_meta_set_i64 (buf, off, vvec_meta_ref_i64 (buf, off) + delta);
}


static int
vvec_node_is_deleted (buffer_desc_t * buf)
{
  return 0 != (vvec_meta_ref_i32 (buf, VVEC_NODE_FLAGS) & VVEC_NODE_DELETED);
}


static int
vvec_node_has_overflow (buffer_desc_t * buf)
{
  return 0 != (vvec_meta_ref_i32 (buf, VVEC_NODE_FLAGS) & VVEC_NODE_OVERFLOW);
}


static void
vvec_node_set_deleted (buffer_desc_t * buf)
{
  vvec_meta_set_i32 (buf, VVEC_NODE_FLAGS, vvec_meta_ref_i32 (buf, VVEC_NODE_FLAGS) | VVEC_NODE_DELETED);
}


static int *
vvec_node_counts_ptr (buffer_desc_t * buf)
{
  return (int *) (buf->bd_buffer + VVEC_NODE_COUNTS);
}


static dp_addr_t *
vvec_node_neighbors_ptr (buffer_desc_t * buf)
{
  return (dp_addr_t *) (buf->bd_buffer + VVEC_NODE_COUNTS + (VVEC_MAX_LAYERS * sizeof (int32)));
}


static dp_addr_t *
vvec_node_layer_ptr (buffer_desc_t * buf, int hnsw_m, int layer)
{
  return vvec_node_neighbors_ptr (buf) + vvec_node_layer_base (hnsw_m, layer);
}


static db_buf_t
vvec_node_vector_ptr (buffer_desc_t * buf, int hnsw_m)
{
  return buf->bd_buffer + vvec_node_vector_offset (hnsw_m);
}


static dp_addr_t
vvec_node_overflow_head (buffer_desc_t * buf, int hnsw_m)
{
  return (dp_addr_t) LONG_REF (vvec_node_vector_ptr (buf, hnsw_m) + VVEC_NODE_OVERFLOW_HEAD_OFF);
}


static int32
vvec_node_overflow_bytes (buffer_desc_t * buf, int hnsw_m)
{
  return LONG_REF (vvec_node_vector_ptr (buf, hnsw_m) + VVEC_NODE_OVERFLOW_BYTES_OFF);
}


static void
vvec_node_set_overflow (buffer_desc_t * buf, int hnsw_m, dp_addr_t head_dp, int32 total_bytes)
{
  db_buf_t ptr = vvec_node_vector_ptr (buf, hnsw_m);
  vvec_meta_set_i32 (buf, VVEC_NODE_FLAGS, vvec_meta_ref_i32 (buf, VVEC_NODE_FLAGS) | VVEC_NODE_OVERFLOW);
  LONG_SET (ptr + VVEC_NODE_OVERFLOW_HEAD_OFF, head_dp);
  LONG_SET (ptr + VVEC_NODE_OVERFLOW_BYTES_OFF, total_bytes);
}


/* ---- Phase 4: packed page accessor functions ---- */

static int
vvec_cn_record_bytes (int dim, int max_layer, int total_neighbors, int has_overflow)
{
  int n_layers = max_layer + 1;
  int vec_bytes = has_overflow ? VVEC_NODE_OVERFLOW_REF_BYTES : (dim * sizeof (float));
  return VVEC_CN_FIXED_BYTES + n_layers + (total_neighbors * sizeof (vvec_node_ref_t)) + vec_bytes;
}

static db_buf_t
vvec_pk_node_ptr (buffer_desc_t * buf, int slot)
{
  uint16 off = SHORT_REF (buf->bd_buffer + VVEC_PK_DIR_BASE + (slot * VVEC_PK_DIR_ENTRY_BYTES));
  if (off == 0)
    return NULL;
  return buf->bd_buffer + DP_DATA + off;
}

static int
vvec_pk_node_count (buffer_desc_t * buf)
{
  return (int) buf->bd_buffer[VVEC_PK_NODE_COUNT];
}

static int
vvec_page_role (buffer_desc_t * buf)
{
  return LONG_REF (buf->bd_buffer + DP_DATA + 4);
}

static int
vvec_cn_max_layer (db_buf_t cn) { return (int) cn[VVEC_CN_MAX_LAYER]; }
static int
vvec_cn_is_deleted (db_buf_t cn) { return 0 != (cn[VVEC_CN_FLAGS] & VVEC_NODE_DELETED); }
static int
vvec_cn_has_overflow (db_buf_t cn) { return 0 != (cn[VVEC_CN_FLAGS] & VVEC_NODE_OVERFLOW); }
static int
vvec_cn_dim (db_buf_t cn) { return (int) SHORT_REF (cn + VVEC_CN_DIM); }
static float
vvec_cn_magnitude (db_buf_t cn) { return vvec_float_ref (cn + VVEC_CN_MAGNITUDE); }
static int64
vvec_cn_d_id (db_buf_t cn) { return INT64_REF (cn + VVEC_CN_D_ID); }
static int
vvec_cn_n_layers (db_buf_t cn) { return (int) cn[VVEC_CN_N_LAYERS]; }

static vvec_node_ref_t *
vvec_cn_neighbors_ptr (db_buf_t cn)
{
  return (vvec_node_ref_t *) (cn + VVEC_CN_COUNTS_BASE + vvec_cn_n_layers (cn));
}

static int
vvec_cn_total_neighbors (db_buf_t cn)
{
  int n = vvec_cn_n_layers (cn), total = 0, i;
  for (i = 0; i < n; i++)
    total += cn[VVEC_CN_COUNTS_BASE + i];
  return total;
}

static db_buf_t
vvec_cn_vector_ptr (db_buf_t cn)
{
  return cn + VVEC_CN_COUNTS_BASE + vvec_cn_n_layers (cn) + (vvec_cn_total_neighbors (cn) * sizeof (vvec_node_ref_t));
}

static int
vvec_cn_layer_base (db_buf_t cn, int layer)
{
  int base = 0, i;
  for (i = 0; i < layer; i++)
    base += cn[VVEC_CN_COUNTS_BASE + i];
  return base;
}

static dp_addr_t
vvec_cn_overflow_head (db_buf_t cn)
{
  return (dp_addr_t) LONG_REF (vvec_cn_vector_ptr (cn) + VVEC_NODE_OVERFLOW_HEAD_OFF);
}

static int32
vvec_cn_overflow_bytes (db_buf_t cn)
{
  return LONG_REF (vvec_cn_vector_ptr (cn) + VVEC_NODE_OVERFLOW_BYTES_OFF);
}


static int
vvec_model_shape_dim (const char *shape)
{
  const char *comma;
  if (!shape || !shape[0])
    return 0;
  comma = strrchr (shape, ',');
  if (comma && comma[1])
    return atoi (comma + 1);
  return atoi (shape);
}


static void
vvec_name_sanitize (char *dst, size_t dst_len, const char *src)
{
  size_t fill = 0;
  while (src && *src && fill + 1 < dst_len)
    {
      char ch = *src++;
      if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9'))
	dst[fill++] = ch;
      else
	dst[fill++] = '_';
    }
  dst[fill] = 0;
}


static char *
vvec_hidden_table_name (dbe_table_t * tb, const char *index_name)
{
  char safe_index[MAX_NAME_LEN * 3];
  char full_name[MAX_QUAL_NAME_LEN + MAX_NAME_LEN * 3];
  vvec_name_sanitize (safe_index, sizeof (safe_index), index_name);
  if (tb->tb_name && !stricmp (tb->tb_name, "DB.DBA.RDF_OBJ"))
    snprintf (full_name, sizeof (full_name), "%s.%s.%s%s_embeddings", tb->tb_qualifier, tb->tb_owner,
	strnicmp (safe_index, "RDF_OBJ_", 8) ? "RDF_OBJ_" : "", safe_index);
  else
    snprintf (full_name, sizeof (full_name), "%s.%s.%s_vec_embeddings", tb->tb_qualifier, tb->tb_owner, safe_index);
  return box_string (full_name);
}


static void
vvec_trigger_short_name (char *dst, size_t dst_len, const char *index_name, const char *suffix)
{
  char safe_index[MAX_NAME_LEN * 3];
  size_t suffix_len = strlen (suffix);
  size_t max_index_len = dst_len > suffix_len + 2 ? dst_len - suffix_len - 2 : 0;
  vvec_name_sanitize (safe_index, sizeof (safe_index), index_name);
  snprintf (dst, dst_len, "%.*s_%s", (int) max_index_len, safe_index, suffix);
}


static char *
vvec_quote_ident (const char *ident)
{
  size_t len = 3;
  const char *src;
  char *ret;
  char *dst;
  for (src = ident; src && *src; src++)
    len += ('"' == *src) ? 2 : 1;
  ret = (char *) dk_alloc_box (len, DV_STRING);
  dst = ret;
  *dst++ = '"';
  for (src = ident; src && *src; src++)
    {
      if ('"' == *src)
	*dst++ = '"';
      *dst++ = *src;
    }
  *dst++ = '"';
  *dst = 0;
  return ret;
}


static char *
vvec_quote_qname (const char *qname)
{
  size_t len = 4 + (qname ? (3 * strlen (qname)) : 0);
  const char *src;
  char *ret;
  char *dst;
  int part_open = 0;
  ret = (char *) dk_alloc_box (len, DV_STRING);
  dst = ret;
  for (src = qname; src && *src; src++)
    {
      if (!part_open)
	{
	  *dst++ = '"';
	  part_open = 1;
	}
      if ('.' == *src)
	{
	  *dst++ = '"';
	  *dst++ = '.';
	  part_open = 0;
	}
      else
	{
	  if ('"' == *src)
	    *dst++ = '"';
	  *dst++ = *src;
	}
    }
  if (part_open)
    *dst++ = '"';
  *dst = 0;
  return ret;
}


static char *
vvec_quote_trigger_qname (dbe_table_t * tb, const char *trigger_name)
{
  char full_name[MAX_QUAL_NAME_LEN + MAX_NAME_LEN * 3];
  snprintf (full_name, sizeof (full_name), "%s.%s.%s", tb->tb_qualifier, tb->tb_owner, trigger_name);
  return vvec_quote_qname (full_name);
}


static char *
vvec_quote_sql_literal (const char *str)
{
  size_t len = 3;
  const char *src;
  char *ret;
  char *dst;
  for (src = str; src && *src; src++)
    len += ('\'' == *src) ? 2 : 1;
  ret = (char *) dk_alloc_box (len, DV_STRING);
  dst = ret;
  *dst++ = '\'';
  for (src = str; src && *src; src++)
    {
      if ('\'' == *src)
	*dst++ = '\'';
      *dst++ = *src;
    }
  *dst++ = '\'';
  *dst = 0;
  return ret;
}


/* Serializes the fresh SQL compilation vvec does on the write path (the hidden
 * table upsert/delete/lookup and the epoch-catalog upsert are compiled per
 * call).  Compilation cost-estimates the target key via key_count_estimate(),
 * which samples the B-tree and caches column statistics on the shared dbe_key_t;
 * that sampling is not re-entrant, so two writers compiling a statement over the
 * same hidden table at once double-free the cached stats and abort the server.
 * Since the hidden tables and the epoch catalog are touched only by this code,
 * serializing vvec's own compilation is sufficient to make concurrent writers
 * safe.  Compilation is brief and off the row-lock path, so this global lock is
 * not a throughput concern; the per-index writer lock still governs the graph.
 */
static dk_mutex_t * vvec_compile_mtx = NULL;

static query_t *
vvec_compile_text (client_connection_t * cli, caddr_t * err, const char *text)
{
  query_t * qr;
  user_t * saved_user = cli->cli_user;
  if (vvec_compile_mtx)
    mutex_enter (vvec_compile_mtx);
  /* internal catalog/hidden-table statements must not depend on the caller's grants, e.g. SPARQL */
  cli->cli_user = sec_id_to_user (U_ID_DBA);
  qr = sql_compile_static (text, cli, err, SQLC_DEFAULT);
  cli->cli_user = saved_user;
  if (vvec_compile_mtx)
    mutex_leave (vvec_compile_mtx);
  return qr;
}


static void
vvec_exec_text (query_instance_t * qi, const char *text)
{
  caddr_t err = NULL;
  query_t * qr = vvec_compile_text (qi->qi_client, &err, text);
  if (err)
    sqlr_resignal (err);
  err = qr_quick_exec (qr, qi->qi_client, "", NULL, 0);
  qr_free (qr);
  if (SQL_SUCCESS != err)
    sqlr_resignal (err);
}


static void
vvec_exec_text_ignore_error (query_instance_t * qi, const char *text)
{
  QR_RESET_CTX_T (qi->qi_thread)
    {
      vvec_exec_text (qi, text);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      dk_free_tree (err);
    }
  END_QR_RESET;
}


static void
vvec_root_read (it_cursor_t * itc, index_tree_t * it, int mode, buffer_desc_t ** buf_ret)
{
  itc->itc_page = it->it_root;
  ITC_IN_KNOWN_MAP (itc, it->it_root);
  page_wait_access (itc, it->it_root, NULL, buf_ret, mode, RWG_WAIT_ANY);
}


/* Packs (key_id, dp) into one int64 key for lt_vvec_page_images -- dp_addr_t
   is 32 bit, so this is lossless. */
#define VVEC_PAGE_IMAGE_KEY(key_id, dp) ((((int64) (key_id)) << 32) | (uint32) (dp))

/* Stored in lt_vvec_page_images in place of a before-image for a page this
   transaction allocated.  There is no "before" for such a page and none is
   possible, so its first release logs the whole thing.  1 is never a
   dk_alloc () result, so it cannot be mistaken for an image. */
#define VVEC_PAGE_IMAGE_NEW ((int64) 1)


/* Offset of a new-page record, in place of a byte offset: the payload is the
   head of a page whose tail is zeroes, to be applied at 0 with the rest of the
   page cleared.  A tag rather than a new field so that a log written before this
   existed still reads -- its new-page records carry offset 0, length PAGE_SZ,
   which vvec_replay_page () still accepts.

   The other direction does not hold, and there is no encoding that would make it
   hold: a server predating this reads the tag as a byte offset, fails the
   geometry check, and -- because that build still returns an error from replay
   -- rolls back the whole transaction, taking the ordinary rows committed with
   it.  A log written by this build must not be replayed by an older one.  That
   was already true of LOG_VEC_PAGE as a whole (see log.h: an older server
   rejects the record type outright); this widens it from "the graph is not
   restored" to "do not do it at all". */
#define VVEC_LOG_NEW_PAGE (-1)

/* True while this transaction's writes should reach LOG_VEC_PAGE at all --
   same early-out log_insert ()/log_text () use, plus ITC_LTRX being set
   (NULL during recovery replay itself: vvec_replay_page () passes NULL to
   ITC_INIT, and replay must never re-log what it is replaying). */
#define VVEC_PAGE_SHOULD_LOG(itc) \
  ((itc)->itc_ltrx && REPL_NO_LOG != (itc)->itc_ltrx->lt_replicate && !cl_non_logged_write_mode)


/* The most DPF_VEC pages any one transaction has held in lt_vvec_page_images
   at once since the last reset: pages in flight between the point they are
   allocated or snapshotted and the point they are released, each costing
   PAGE_SZ while it is there.  This is the number that used to grow with the
   size of a transaction rather than with what it had open -- a rebuild held
   the whole graph -- so it is worth being able to read on a running server,
   and __vvec_page_image_peak () is how.

   Sampled under the owning transaction's lt_log_mtx, so each reading of
   ht_count is exact.  The comparison against the global is unsynchronised, in
   the same way as Virtuoso's other TC () statistics: two transactions peaking
   together can lose an update and report one notch low.  That is the right
   trade for a counter sitting on the write path, and this is a diagnostic
   rather than something correctness depends on. */
static int64 vvec_page_image_peak = 0;

/* Call with LT's lt_log_mtx held, just after adding an entry. */
static void
vvec_page_image_peak_note (lock_trx_t * lt)
{
  int64 held = lt->lt_vvec_page_images ? (int64) lt->lt_vvec_page_images->ht_count : 0;
  if (held > vvec_page_image_peak)
    vvec_page_image_peak = held;
}


static buffer_desc_t *
it_new_vec_page (index_tree_t * it, dp_addr_t near_dp, it_cursor_t * has_hold)
{
  /* No growth-threshold promotion to a private extent map here, the way
     itc_hold_pages () does it for a B-tree.  A freed page is returned to its own
     map only when the tree has column extent maps; otherwise checkpoint returns
     it to whichever map the tree holds at that moment (neodisk.c:1436-1438).  A
     vector index has none, so promoting it part-way through its life would give
     back every page allocated before the promotion to a map that never owned
     them, and unlike a B-tree -- which frees piecemeal -- vvec_graph_reset ()
     frees the whole graph on every rebuild, so that set is the common case
     rather than a corner.  Nothing currently rests on the check this would have
     strengthened: DBS_DP_TO_EM () in vvec_replay_page () is belt to
     vvec_replay_page_is_ours ()'s braces, and that is what proves ownership.  To
     have a private map, this index needs it from its first page -- or the free
     path needs the per-page lookup the column-store branch already uses. */
  buffer_desc_t * buf = it_new_page (it, near_dp, DPF_INDEX, 0, has_hold);
  SHORT_SET (buf->bd_buffer + DP_FLAGS, DPF_VEC);
  /* it_new_page () clears the 20-byte header and leaves the rest of the buffer
     holding whatever page last occupied it.  Each caller below then clears the
     part it is about to use, from a different offset each time, which leaves the
     tail zero in every case that exists today -- but by five coincidences rather
     than by construction, and vvec_page_image_len () now depends on it: a page
     whose tail is stale bytes logs them, and replay, which zeroes the page it
     allocates, would not reproduce them.  Clear it once, here. */
  memset (buf->bd_buffer + DP_DATA, 0, PAGE_SZ - DP_DATA);
  /* Record that this transaction owns the page.  Two things follow from it:
     the page's first release logs a full image, which is what
     vvec_replay_page () requires to initialize a page the allocator still
     believes is free; and lt_vvec_page_images becomes a complete answer to
     "did THIS transaction write this page", which is what lets
     vvec_page_release () stop inferring it from bd_is_dirty. */
  if (has_hold && VVEC_PAGE_SHOULD_LOG (has_hold) && it->it_key)
    {
      lock_trx_t * lt = has_hold->itc_ltrx;
      int64 ik = VVEC_PAGE_IMAGE_KEY (it->it_key->key_id, buf->bd_page);
      int64 stale = 0;
      mutex_enter (lt->lt_log_mtx);
      if (!lt->lt_vvec_page_images)
	{
	  /* One entry per vector page this transaction touches; a bulk build's
	     serialize phase touches them by the million.  See the note in
	     vvec_free_node_chain () on why the rehash has to be asked for. */
	  lt->lt_vvec_page_images = hash_table_allocate_64 (4096);
	  id_hash_set_rehash_pct (lt->lt_vvec_page_images, 120);
	}
      else
	gethash_64 (stale, ik, lt->lt_vvec_page_images);
      sethash_64 (ik, lt->lt_vvec_page_images, VVEC_PAGE_IMAGE_NEW);
      vvec_page_image_peak_note (lt);
      mutex_leave (lt->lt_log_mtx);
      /* The allocator can hand back a page this same transaction freed -- a
	 rebuild frees the old graph and then builds the new one.  Its image
	 describes a page that no longer exists, so drop it rather than leak
	 it under the entry just overwritten. */
      if (stale && VVEC_PAGE_IMAGE_NEW != stale)
	dk_free ((caddr_t) (ptrlong) stale, PAGE_SZ);
    }
  return buf;
}

/* Chunk the scan below compares at a time before descending to bytes.  Large
   enough that a whole page is a couple of dozen memcmp () calls instead of
   8192 loads and branches, small enough that the byte refinement inside the
   one chunk at each end stays trivial. */
#define VVEC_DIFF_CHUNK 256

/* The range [*FIRST_RET, *LAST_RET] outside which NOW is identical to BEFORE,
   i.e. the smallest byte range a LOG_VEC_PAGE record has to carry to turn one
   into the other.  Returns 0 when the page did not change, in which case there
   is nothing to log at all.

   This runs on every logged page release, so it walks the page with memcmp ()
   -- which the C library vectorises -- and only falls back to a byte at a time
   inside the first and the last chunk that differ.  The result is
   byte-identical to comparing the whole page one byte at a time, which it has
   to be: the record names a byte range and redo writes exactly that range, so
   a first that is one too high silently drops a byte from the graph. */
static int
vvec_page_changed_range (db_buf_t before, db_buf_t now, int * first_ret, int * last_ret)
{
  int off, inx, len, start, first = -1, last = -1;

  for (off = 0; off < PAGE_SZ; off += VVEC_DIFF_CHUNK)
    {
      len = PAGE_SZ - off < VVEC_DIFF_CHUNK ? PAGE_SZ - off : VVEC_DIFF_CHUNK;
      if (0 != memcmp (before + off, now + off, len))
	{
	  for (inx = off; inx < off + len; inx++)
	    if (before[inx] != now[inx])
	      {
		first = inx;
		break;
	      }
	  break;
	}
    }
  if (first < 0)
    return 0;
  /* Backwards for the far end.  The chunk holding FIRST differs by
     construction, so this always finds something and cannot run past it. */
  for (off = PAGE_SZ; off > first; off -= VVEC_DIFF_CHUNK)
    {
      start = off - VVEC_DIFF_CHUNK;
      if (start < first)
	start = first;
      if (0 != memcmp (before + start, now + start, off - start))
	{
	  for (inx = off - 1; inx >= start; inx--)
	    if (before[inx] != now[inx])
	      {
		last = inx;
		break;
	      }
	  break;
	}
    }
  *first_ret = first;
  *last_ret = last;
  return 1;
}


/* Where a new page's content ends and its trailing zeroes begin.  Everything
   past that is what it_new_vec_page () cleared and nothing wrote, and replay
   re-creates it for free -- it_new_page_exact () hands back a zeroed page -- so
   logging it costs a full PAGE_SZ per inserted row to say "still zero".  A node
   at dim 8 / hnsw_m 8 writes about 712 bytes of that page; at dim 384, about
   2740.  A page that really is full logs in full, which is correct rather than
   wasteful.  The header is always included, so the image stays self-identifying.
   Stepping a chunk at a time because the run being measured is the long one. */
static int
vvec_page_image_len (db_buf_t page)
{
  static const unsigned char zero[64] = { 0 };
  int n = PAGE_SZ;
  while (n - (int) sizeof (zero) >= DP_DATA && !memcmp (page + n - sizeof (zero), zero, sizeof (zero)))
    n -= (int) sizeof (zero);
  while (n > DP_DATA && !page[n - 1])
    n--;
  return n;
}


static void
vvec_page_release (it_cursor_t * itc, buffer_desc_t * buf)
{
  if (buf && VVEC_PAGE_SHOULD_LOG (itc) && buf->bd_tree && buf->bd_tree->it_key)
    {
      lock_trx_t * lt = itc->itc_ltrx;
      int64 ik = VVEC_PAGE_IMAGE_KEY (buf->bd_tree->it_key->key_id, buf->bd_page);
      int64 have = 0;
      /* Presence in lt_vvec_page_images is the whole predicate.  This
	 transaction is in there for a page it allocated (VVEC_PAGE_IMAGE_NEW,
	 from it_new_vec_page ()) or one it took a before-image of
	 (vvec_page_delta ()), and those are the only two ways vvec.c writes a
	 page -- so a page that is absent is one this transaction merely read,
	 and it produces no record.

	 bd_is_dirty cannot answer this question.  A DPF_VEC page stays dirty
	 from the write that touched it until the next checkpoint, so a
	 dirty-page rule reads "log every graph page any search visits after
	 anyone wrote it", which is how a read-only SELECT ends up appending
	 megabytes of page images to its own transaction's log
	 (tvvec_page_log.sh measures exactly this).

	 The entry is taken OUT here rather than folded and kept.  An image is
	 only ever read by the release that follows the delta that made it; a
	 later mutation of the same page in this transaction goes through
	 vvec_page_delta () again and re-snapshots, so the next delta is
	 relative to the right base either way.  Keeping it would hold PAGE_SZ
	 per page touched until commit -- for a rebuild, the entire graph.

	 lt_log_mtx guards the hash itself (an MT transaction can have branch
	 threads writing different indexes under the same lt concurrently --
	 vvec_writer_lock () only serializes writers to one index).  It is
	 released before log_vec_page (), which takes the same mutex itself;
	 the image this thread removed is now private to it. */
      mutex_enter (lt->lt_log_mtx);
      if (lt->lt_vvec_page_images)
	{
	  gethash_64 (have, ik, lt->lt_vvec_page_images);
	  if (have)
	    remhash_64 (ik, lt->lt_vvec_page_images);
	}
      mutex_leave (lt->lt_log_mtx);
      if (VVEC_PAGE_IMAGE_NEW == have)
	{
	  /* A new page must be represented by a complete, self-identifying
	     image: a delta cannot initialize storage, and vvec_replay_page ()
	     refuses one that tries.  Complete does not mean PAGE_SZ, though --
	     the trailing zeroes are re-created by the page replay allocates. */
	  log_vec_page (lt, buf->bd_tree->it_key->key_id, buf->bd_page,
	      VVEC_LOG_NEW_PAGE, buf->bd_buffer, vvec_page_image_len (buf->bd_buffer));
	}
      else if (have)
	{
	  db_buf_t before = (db_buf_t) (ptrlong) have;
	  int first, last;
	  if (vvec_page_changed_range (before, buf->bd_buffer, &first, &last))
	    log_vec_page (lt, buf->bd_tree->it_key->key_id, buf->bd_page,
		first, buf->bd_buffer + first, last - first + 1);
	  dk_free ((caddr_t) before, PAGE_SZ);
	}
    }
  page_leave_outside_map (buf);
}


/* it_free_page() requires the caller to hold the page's map mutex and returns with that
   mutex still held (libsrc/Wi/space.c).  It is entered *around* the call rather than held
   across it because it_free_page() itself leaves the map to cancel a queued background
   write -- see the note in buf_cancel_write() (libsrc/Wi/mtwrite.c) on why the caller must
   own the buffer but not be in its tree's map at that moment.

   Every vvec page helper leaves the map before returning -- page_wait_access() does
   ITC_LEAVE_MAPS, vvec_page_delta() does ITC_LEAVE_MAP_NC -- so each free has to re-enter
   it.  Without this, the mutex_leave() inside it_free_page() is a no-op (this thread is not
   the owner) and its paired mutex_enter() genuinely acquires the mutex, which then leaks:
   the next ITC_IN_KNOWN_MAP sees itc_itm1 == NULL and blocks re-locking a mutex this thread
   already holds.  Read bd_page before the call: page_leave_as_deleted() zeroes it. */
static void
vvec_page_free (it_cursor_t * itc, index_tree_t * it, buffer_desc_t * buf)
{
  /* Drop any in-flight before-image first: the page is about to stop existing,
     so there is nothing left to log a delta against, and the allocator may
     hand the same dp back to this same transaction (a rebuild frees the old
     graph and then builds the new one).  Freeing a page never goes through
     vvec_page_release (), so this is the only place that can do it. */
  if (VVEC_PAGE_SHOULD_LOG (itc) && it->it_key)
    {
      lock_trx_t * lt = itc->itc_ltrx;
      int64 ik = VVEC_PAGE_IMAGE_KEY (it->it_key->key_id, buf->bd_page);
      int64 have = 0;
      mutex_enter (lt->lt_log_mtx);
      if (lt->lt_vvec_page_images)
	{
	  gethash_64 (have, ik, lt->lt_vvec_page_images);
	  if (have)
	    remhash_64 (ik, lt->lt_vvec_page_images);
	}
      mutex_leave (lt->lt_log_mtx);
      if (have && VVEC_PAGE_IMAGE_NEW != have)
	dk_free ((caddr_t) (ptrlong) have, PAGE_SZ);
    }
  ITC_IN_KNOWN_MAP (itc, buf->bd_page);
  it_free_page (it, buf);
  ITC_LEAVE_MAP_NC (itc);
}


static buffer_desc_t *
vvec_page_delta (it_cursor_t * itc, buffer_desc_t * buf)
{
  ITC_IN_KNOWN_MAP (itc, buf->bd_page);
  buf = itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
  ITC_LEAVE_MAP_NC (itc);
  /* Before-image on first touch: itc_delta_this_buffer () just did the CoW
     remap, so buf->bd_buffer here is still byte-for-byte the page's content
     as of the start of this transaction (the caller has not written into it
     yet) -- exactly once per (key_id, dp) per transaction, since a second
     vvec_page_delta () on the same page in the same transaction finds the
     page already remapped and this snapshot already present. vvec.c itself
     is unchanged below this point: it keeps writing into buf->bd_buffer
     exactly as before. */
  if (buf && VVEC_PAGE_SHOULD_LOG (itc) && buf->bd_tree && buf->bd_tree->it_key)
    {
      lock_trx_t * lt = itc->itc_ltrx;
      int64 ik = VVEC_PAGE_IMAGE_KEY (buf->bd_tree->it_key->key_id, buf->bd_page);
      int64 have = 0;
      /* lt_log_mtx guards lt_vvec_page_images -- see the note in
	 vvec_page_release (), the paired reader/updater of this hash. */
      mutex_enter (lt->lt_log_mtx);
      if (!lt->lt_vvec_page_images)
	{
	  lt->lt_vvec_page_images = hash_table_allocate_64 (4096);
	  id_hash_set_rehash_pct (lt->lt_vvec_page_images, 120);
	}
      else
	gethash_64 (have, ik, lt->lt_vvec_page_images);
      if (!have)
	{
	  db_buf_t image = (db_buf_t) dk_alloc (PAGE_SZ);
	  memcpy (image, buf->bd_buffer, PAGE_SZ);
	  sethash_64 (ik, lt->lt_vvec_page_images, (int64) (ptrlong) image);
	  vvec_page_image_peak_note (lt);
	}
      mutex_leave (lt->lt_log_mtx);
    }
  return buf;
}


static void
vvec_page_access (it_cursor_t * itc, dp_addr_t dp, int mode, buffer_desc_t ** buf_ret)
{
  itc->itc_page = dp;
  ITC_IN_KNOWN_MAP (itc, dp);
  page_wait_access (itc, dp, NULL, buf_ret, mode, RWG_WAIT_ANY);
}


static int
vvec_extract_floats (caddr_t vec, float **data_ret, int *dim_ret)
{
  dtp_t dtp;
  int len;
  float *data;
  int inx;
  if (!vec)
    return 0;
  dtp = DV_TYPE_OF (vec);
  if (DV_ARRAY_OF_FLOAT == dtp)
    {
      len = box_length (vec) / sizeof (float);
      if (!len)
	return 0;
      data = (float *) dk_alloc (len * sizeof (float));
      memcpy (data, vec, len * sizeof (float));
      *data_ret = data;
      *dim_ret = len;
      return 1;
    }
  if (DV_ARRAY_OF_POINTER != dtp)
    return 0;
  len = BOX_ELEMENTS (vec);
  if (!len)
    return 0;
  data = (float *) dk_alloc (len * sizeof (float));
  for (inx = 0; inx < len; inx++)
    {
      caddr_t elt = ((caddr_t *) vec)[inx];
      switch (DV_TYPE_OF (elt))
	{
	case DV_SINGLE_FLOAT:
	  data[inx] = unbox_float (elt);
	  break;
	case DV_DOUBLE_FLOAT:
	  data[inx] = (float) unbox_double (elt);
	  break;
	case DV_NUMERIC:
	  {
	    double dval = 0;
	    numeric_to_double ((numeric_t) elt, &dval);
	    data[inx] = (float) dval;
	    break;
	  }
	default:
	  data[inx] = (float) unbox (elt);
	  break;
	}
    }
  *data_ret = data;
  *dim_ret = len;
  return 1;
}


/* The stored/exchanged form of an embedding is DV_ARRAY_OF_FLOAT: vvec_extract_floats
   reads it back with one memcpy, where a DV_ARRAY_OF_POINTER costs an unbox per
   dimension -- 384 per row, ~3.7e9 over a 9.7M-row rebuild. */
static caddr_t
vvec_float_box (const float * data, int dim)
{
  caddr_t box = dk_alloc_box (dim * sizeof (float), DV_ARRAY_OF_FLOAT);
  memcpy (box, data, dim * sizeof (float));
  return box;
}


/* Any accepted vector form -> a fresh DV_ARRAY_OF_FLOAT box.  NULL if vec is not
   a vector at all.  Lossless: both forms carry float32 values. */
static caddr_t
vvec_to_float_box (caddr_t vec)
{
  float * data = NULL;
  int dim = 0;
  caddr_t box;
  if (DV_ARRAY_OF_FLOAT == DV_TYPE_OF (vec))
    return vvec_float_box ((const float *) vec, box_length (vec) / sizeof (float));
  if (!vvec_extract_floats (vec, &data, &dim))
    return NULL;
  box = vvec_float_box (data, dim);
  dk_free ((caddr_t) data, dim * sizeof (float));
  return box;
}


static caddr_t
vvec_make_test_vector_box (int dim, int pos1, int pos2)
{
  float * vec = (float *) dk_alloc_box_zero (dim * sizeof (float), DV_ARRAY_OF_FLOAT);
  if (pos1 >= 0 && pos1 < dim)
    vec[pos1] = 1.0f;
  if (pos2 >= 0 && pos2 < dim)
    vec[pos2] = 1.0f;
  return (caddr_t) vec;
}


static int
vvec_write_overflow_vector (it_cursor_t * itc, vvec_meta_t * meta, dp_addr_t near_dp, const float *vec, dp_addr_t * head_ret)
{
  int total_bytes = meta->vm_dimension * sizeof (float);
  int remaining = total_bytes;
  int copied = 0;
  int pages = 0;
  int cap = vvec_overflow_payload_capacity ();
  dp_addr_t head = 0;
  buffer_desc_t * prev = NULL;
  if (total_bytes <= 0 || cap <= 0)
    sqlr_new_error ("42000", "VEC60", "Invalid vector overflow storage geometry.");
  while (remaining > 0)
    {
      int chunk = remaining < cap ? remaining : cap;
      buffer_desc_t * ov = it_new_vec_page (meta->vm_it, near_dp ? near_dp : meta->vm_it->it_root, itc);
      dp_addr_t ov_dp = ov->bd_page;
      if (!head)
	head = ov_dp;
      if (prev)
	{
	  vvec_meta_set_i32 (prev, VVEC_OV_NEXT_DP, ov_dp);
	  vvec_page_release (itc, prev);
	}
      memset (ov->bd_buffer + DP_DATA, 0, PAGE_SZ - DP_DATA);
      vvec_meta_set_i32 (ov, VVEC_OV_MAGIC, VVEC_MAGIC);
      vvec_meta_set_i32 (ov, VVEC_OV_ROLE, VVEC_ROLE_OVERFLOW);
      vvec_meta_set_i32 (ov, VVEC_OV_VERSION, VVEC_VERSION);
      vvec_meta_set_i32 (ov, VVEC_OV_FLAGS, 0);
      vvec_meta_set_i32 (ov, VVEC_OV_NEXT_DP, 0);
      vvec_meta_set_i32 (ov, VVEC_OV_BYTES, chunk);
      vvec_meta_set_i32 (ov, VVEC_OV_TOTAL_BYTES, total_bytes);
      SHORT_SET (ov->bd_buffer + DP_LAST_INSERT, VVEC_VERSION);
      memcpy (ov->bd_buffer + VVEC_OV_DATA, ((db_buf_t) vec) + copied, chunk);
      remaining -= chunk;
      copied += chunk;
      pages++;
      near_dp = ov_dp;
      prev = ov;
    }
  if (prev)
    vvec_page_release (itc, prev);
  *head_ret = head;
  return pages;
}


static void
vvec_read_overflow_vector (it_cursor_t * itc, buffer_desc_t * node, int hnsw_m, int dim, float *dst)
{
  int expected_bytes = dim * sizeof (float);
  int copied = 0;
  int cap = vvec_overflow_payload_capacity ();
  dp_addr_t next = vvec_node_overflow_head (node, hnsw_m);
  if (!next || vvec_node_overflow_bytes (node, hnsw_m) != expected_bytes)
    sqlr_new_error ("42000", "VEC60", "Corrupt vector overflow reference.");
  while (next && copied < expected_bytes)
    {
      buffer_desc_t * ov = NULL;
      int bytes;
      dp_addr_t cur = next;
      vvec_page_access (itc, cur, PA_READ, &ov);
      if (vvec_meta_ref_i32 (ov, VVEC_OV_MAGIC) != VVEC_MAGIC
	  || vvec_meta_ref_i32 (ov, VVEC_OV_ROLE) != VVEC_ROLE_OVERFLOW
	  || vvec_meta_ref_i32 (ov, VVEC_OV_VERSION) != VVEC_VERSION)
	{
	  vvec_page_release (itc, ov);
	  sqlr_new_error ("42000", "VEC60", "Corrupt vector overflow page %ld.", (long) cur);
	}
      bytes = vvec_meta_ref_i32 (ov, VVEC_OV_BYTES);
      if (bytes <= 0 || bytes > cap || bytes > expected_bytes - copied)
	{
	  vvec_page_release (itc, ov);
	  sqlr_new_error ("42000", "VEC60", "Corrupt vector overflow payload on page %ld.", (long) cur);
	}
      memcpy (((db_buf_t) dst) + copied, ov->bd_buffer + VVEC_OV_DATA, bytes);
      copied += bytes;
      next = vvec_meta_ref_i32 (ov, VVEC_OV_NEXT_DP);
      vvec_page_release (itc, ov);
    }
  if (copied != expected_bytes || next)
    sqlr_new_error ("42000", "VEC60", "Incomplete vector overflow chain.");
}


/* Phase 4: read overflow vector from a head dp + total_bytes (for packed nodes). */
static void
vvec_read_overflow_from_head (it_cursor_t * itc, vvec_meta_t * meta, dp_addr_t head, int32 total_bytes, int dim, float *dst)
{
  int expected_bytes = dim * sizeof (float);
  int copied = 0;
  int cap = vvec_overflow_payload_capacity ();
  dp_addr_t next = head;
  if (!next || total_bytes != expected_bytes)
    sqlr_new_error ("42000", "VEC60", "Corrupt vector overflow reference.");
  while (next && copied < expected_bytes)
    {
      buffer_desc_t * ov = NULL;
      int bytes;
      dp_addr_t cur = next;
      vvec_page_access (itc, cur, PA_READ, &ov);
      bytes = vvec_meta_ref_i32 (ov, VVEC_OV_BYTES);
      if (bytes <= 0 || bytes > cap || bytes > expected_bytes - copied)
	{
	  vvec_page_release (itc, ov);
	  sqlr_new_error ("42000", "VEC60", "Corrupt vector overflow payload on page %ld.", (long) cur);
	}
      memcpy (((db_buf_t) dst) + copied, ov->bd_buffer + VVEC_OV_DATA, bytes);
      copied += bytes;
      next = vvec_meta_ref_i32 (ov, VVEC_OV_NEXT_DP);
      vvec_page_release (itc, ov);
    }
  if (copied != expected_bytes || next)
    sqlr_new_error ("42000", "VEC60", "Incomplete vector overflow chain.");
}


static void
vvec_node_copy_vector (it_cursor_t * itc, buffer_desc_t * buf, int hnsw_m, int dim, float *dst)
{
  int inx;
  if (vvec_node_has_overflow (buf))
    {
      vvec_read_overflow_vector (itc, buf, hnsw_m, dim, dst);
      return;
    }
  db_buf_t vec = vvec_node_vector_ptr (buf, hnsw_m);
  for (inx = 0; inx < dim; inx++)
    dst[inx] = vvec_float_ref (vec + (inx * sizeof (float)));
}


static float
vvec_vector_magnitude (const float *vec, int dim)
{
  /* perf phase 1: SIMD float32 kernel (see vvec_simd.h). */
  return vvec_norm_f32 (vec, dim);
}


static void
vvec_apply_reduction (vvec_meta_t * meta, float **vec, int *dim)
{
  int target_dim;
  int native_dim;
  int inx;
  double sum = 0;
  double mag;
  float * reduced;
  if (!meta || !vec || !*vec || !dim || VVEC_REDUCE_TRUNCATE != meta->vm_reduce)
    return;
  target_dim = meta->vm_dimension;
  native_dim = *dim;
  if (target_dim <= 0 || native_dim <= target_dim)
    return;
  if (meta->vm_native_dimension > 0 && native_dim != meta->vm_native_dimension)
    return;
  reduced = (float *) dk_alloc (target_dim * sizeof (float));
  for (inx = 0; inx < target_dim; inx++)
    {
      reduced[inx] = (*vec)[inx];
      sum += ((double) reduced[inx]) * ((double) reduced[inx]);
    }
  /* MRL truncation preserves embedding quality only for models trained with
   * Matryoshka Representation Learning; other models may lose quality.
   * The unconditional L2 renormalization below assumes cosine-style similarity;
   * for euclidean/manhattan (L2/L1) metrics, truncation + renormalization
   * changes magnitude semantics and is intended only for MRL-trained models
   * used with cosine distance. */
  mag = sqrt (sum);
  if (mag > 0)
    {
      for (inx = 0; inx < target_dim; inx++)
	reduced[inx] = (float) (((double) reduced[inx]) / mag);
    }
  dk_free ((caddr_t) *vec, native_dim * sizeof (float));
  *vec = reduced;
  *dim = target_dim;
}


static float
vvec_distance_inline (const float *left, float left_mag, const float *right, float right_mag, int dim, int metric)
{
  /* perf phase 1: SIMD float32 kernels (see vvec_simd.h). Accumulate in float32
   * like FAISS/hnswlib; the final cosine division stays in double. */
  double dot;
  if (VVEC_METRIC_L2 == metric)
    return (float) sqrt ((double) vvec_l2sqr_f32 (left, right, dim));
  if (VVEC_METRIC_L1 == metric)
    return vvec_l1_f32 (left, right, dim);
  dot = (double) vvec_ip_f32 (left, right, dim);
  if (!left_mag || !right_mag)
    return 2.0f;
  return (float) (1.0 - (dot / (((double) left_mag) * ((double) right_mag))));
}


static float
vvec_distance_node (it_cursor_t * itc, buffer_desc_t * buf, const float *query, float query_mag, int dim, int metric, int hnsw_m)
{
  /* perf phase 1: the hot traversal kernel. The stored vector is read straight from
   * the page by the SIMD ext kernels (vvec_simd.h), which fuse the on-page
   * big-endian byte-swap into the vectorized load -- no per-element deswizzle, no
   * float->double widening, no intermediate buffer. */
  db_buf_t vec = vvec_node_vector_ptr (buf, hnsw_m);
  float mag = vvec_float_ref (buf->bd_buffer + VVEC_NODE_MAGNITUDE);
  double dot;
  if (vvec_node_has_overflow (buf))
    {
      float * stored = (float *) dk_alloc (dim * sizeof (float));
      float dist;
      vvec_node_copy_vector (itc, buf, hnsw_m, dim, stored);
      dist = vvec_distance_inline (stored, mag, query, query_mag, dim, metric);
      dk_free ((caddr_t) stored, dim * sizeof (float));
      return dist;
    }
  if (VVEC_METRIC_L2 == metric)
    return (float) sqrt ((double) vvec_l2sqr_extf32 ((const unsigned char *) vec, query, dim));
  if (VVEC_METRIC_L1 == metric)
    return vvec_l1_extf32 ((const unsigned char *) vec, query, dim);
  dot = (double) vvec_ip_extf32 ((const unsigned char *) vec, query, dim);
  if (!mag || !query_mag)
    return 2.0f;
  return (float) (1.0 - (dot / (((double) mag) * ((double) query_mag))));
}


static void
vvec_cand_list_init (vvec_cand_list_t * list, int cap)
{
  list->vcl_cap = cap;
  list->vcl_fill = 0;
  list->vcl_items = (vvec_candidate_t *) dk_alloc (cap * sizeof (vvec_candidate_t));
}


static void
vvec_cand_list_free (vvec_cand_list_t * list)
{
  if (list->vcl_items)
    dk_free ((caddr_t) list->vcl_items, list->vcl_cap * sizeof (vvec_candidate_t));
  list->vcl_items = NULL;
  list->vcl_fill = 0;
  list->vcl_cap = 0;
}


static void
vvec_cand_list_insert (vvec_cand_list_t * list, vvec_node_ref_t dp, float distance)
{
  int inx;
  if (list->vcl_fill >= list->vcl_cap)
    {
      int new_cap = list->vcl_cap * 2;
      vvec_candidate_t * items = (vvec_candidate_t *) dk_alloc (new_cap * sizeof (vvec_candidate_t));
      memcpy (items, list->vcl_items, list->vcl_fill * sizeof (vvec_candidate_t));
      dk_free ((caddr_t) list->vcl_items, list->vcl_cap * sizeof (vvec_candidate_t));
      list->vcl_items = items;
      list->vcl_cap = new_cap;
    }
  for (inx = list->vcl_fill; inx > 0; inx--)
    {
      if (list->vcl_items[inx - 1].vc_distance <= distance)
	break;
      list->vcl_items[inx] = list->vcl_items[inx - 1];
    }
  list->vcl_items[inx].vc_dp = dp;
  list->vcl_items[inx].vc_distance = distance;
  list->vcl_fill++;
}


static vvec_candidate_t
vvec_cand_list_pop_first (vvec_cand_list_t * list)
{
  vvec_candidate_t item;
  item = list->vcl_items[0];
  memmove (list->vcl_items, list->vcl_items + 1, (list->vcl_fill - 1) * sizeof (vvec_candidate_t));
  list->vcl_fill--;
  return item;
}


static void
vvec_cand_list_trim (vvec_cand_list_t * list, int limit)
{
  if (list->vcl_fill > limit)
    list->vcl_fill = limit;
}


static int
vvec_cand_list_contains (vvec_cand_list_t * list, vvec_node_ref_t dp)
{
  int inx;
  for (inx = 0; inx < list->vcl_fill; inx++)
    if (list->vcl_items[inx].vc_dp == dp)
      return 1;
  return 0;
}


/* Parse a stored/DDL source_kind option value.  Returns VVEC_SOURCE_VECTOR for
 * "vector", VVEC_SOURCE_TEXT for "text" or an absent/empty value, and -1 for a
 * present-but-unrecognized value (so the DDL layer can reject it). */
static int
vvec_parse_source_kind (caddr_t box)
{
  if (!box || !vvec_is_string_box (box))
    return VVEC_SOURCE_TEXT;
  if (!stricmp ((char *) box, "vector"))
    return VVEC_SOURCE_VECTOR;
  if (!stricmp ((char *) box, "rdf_obj"))
    return VVEC_SOURCE_RDF_OBJ;
  if (!stricmp ((char *) box, "text") || 0 == ((char *) box)[0])
    return VVEC_SOURCE_TEXT;
  return -1;
}


static int
vvec_meta_from_key (dbe_key_t * key, vvec_meta_t * meta)
{
  caddr_t metric_box;
  caddr_t reduce_box;
  memset (meta, 0, sizeof (*meta));
  meta->vm_key = key;
  meta->vm_it = key->key_fragments && key->key_fragments[0] ? key->key_fragments[0]->kf_it : NULL;
  meta->vm_hidden_table = (char *) vvec_opt_value (key->key_options, VVEC_OPT_HIDDEN_TABLE);
  if (!vvec_opt_int_value (key->key_options, VVEC_OPT_MODEL_ID, 0, &meta->vm_model_id))
    meta->vm_model_id = 0;
  if (!vvec_opt_int_value (key->key_options, VVEC_OPT_DIMENSIONS, 0, &meta->vm_dimension))
    meta->vm_dimension = 0;
  if (!vvec_opt_int_value (key->key_options, VVEC_OPT_NATIVE_DIMENSIONS, meta->vm_dimension, &meta->vm_native_dimension))
    meta->vm_native_dimension = meta->vm_dimension;
  reduce_box = vvec_opt_value (key->key_options, VVEC_OPT_REDUCE);
  if (!vvec_parse_reduce (reduce_box, &meta->vm_reduce))
    meta->vm_reduce = -1;
  metric_box = vvec_opt_value (key->key_options, VVEC_OPT_DISTANCE);
  meta->vm_metric = vvec_parse_metric (vvec_is_string_box (metric_box) ? (char *) metric_box : NULL);
  if (!vvec_opt_int_value (key->key_options, VVEC_OPT_HNSW_M, 16, &meta->vm_hnsw_m))
    meta->vm_hnsw_m = 0;
  if (!vvec_opt_int_value (key->key_options, VVEC_OPT_EF_CONSTR, 200, &meta->vm_ef_construction))
    meta->vm_ef_construction = 0;
  meta->vm_rebuild = vvec_parse_rebuild (vvec_opt_value (key->key_options, VVEC_OPT_REBUILD));
  if (meta->vm_rebuild < 0)                 /* an invalid stored value never blocks meta load */
    meta->vm_rebuild = VVEC_REBUILD_UNSET;
  meta->vm_source_kind = vvec_parse_source_kind (vvec_opt_value (key->key_options, VVEC_OPT_SOURCE_KIND));
  if (meta->vm_source_kind < 0)             /* an invalid stored value never blocks meta load */
    meta->vm_source_kind = VVEC_SOURCE_TEXT;
  meta->vm_state = (char *) vvec_opt_value (key->key_options, VVEC_OPT_STATE);
  meta->vm_arena = NULL;    /* perf phase 2: set only on the writer-locked insert path */
  return meta->vm_it && meta->vm_hidden_table && meta->vm_dimension && meta->vm_reduce >= 0 && meta->vm_metric && meta->vm_hnsw_m;
}


static dbe_key_t * vvec_find_key_by_name (const char *index_name);

/* The original implementation called ddl_key_name_to_id, which resolves the
 * key id via a SELECT from DB.DBA.SYS_KEYS filtered by KEY_NAME and the
 * connection's qualifier.  That path is qualifier-sensitive and depends on
 * SYS_KEYS visibility, so it fails to resolve vector-index keys whose table
 * lives in a different qualifier than the current connection.  The in-memory
 * schema scan below is qualifier-independent and mirrors what
 * vvec_find_key_by_name already does for the EXPLAIN path. */
static dbe_key_t *
vvec_find_key (query_instance_t * qi, const char *index_name)
{
  (void) qi;
  return vvec_find_key_by_name (index_name);
}


static dbe_key_t *
vvec_require_key (query_instance_t * qi, const char *func, const char *index_name, vvec_meta_t * meta)
{
  dbe_key_t * key = vvec_find_key (qi, index_name);
  if (!key)
    sqlr_new_error ("42S12", "VEC01", "No vector index %s in %s.", index_name, func);
  if (!vvec_key_p (key))
    sqlr_new_error ("42000", "VEC02", "Index %s is not a vector index.", index_name);
  dbe_key_open (key);
  if (!vvec_meta_from_key (key, meta))
    sqlr_new_error ("42000", "VEC03", "Vector index %s has incomplete metadata.", index_name);
  if (meta->vm_state && stricmp (meta->vm_state, VVEC_STATE_READY_FOR_INTERNAL_LOAD) && stricmp (meta->vm_state, VVEC_STATE_READY))
    sqlr_new_error ("42000", "VEC04", "Vector index %s is not ready for internal load.", index_name);
  return key;
}


static int
vvec_row_id_to_i64 (caddr_t row_id, int64 *row_id_ret)
{
  int64 wanted_id;
  if (!row_id || !row_id_ret)
    return 0;
  if (IS_BOX_POINTER (row_id))
    {
      dtp_t row_dtp = DV_TYPE_OF (row_id);
      if (vvec_is_string_box (row_id))
	{
	  char * end = NULL;
	  wanted_id = strtoll ((char *) row_id, &end, 10);
	  if (!end || end == (char *) row_id || *end)
	    return 0;
	}
      else if (DV_SHORT_INT == row_dtp || DV_LONG_INT == row_dtp || DV_INT64 == row_dtp || DV_NUMERIC == row_dtp)
	wanted_id = (int64) unbox (row_id);
      else if (DV_SINGLE_FLOAT == row_dtp)
	wanted_id = (int64) unbox_float (row_id);
      else if (DV_DOUBLE_FLOAT == row_dtp)
	wanted_id = (int64) unbox_double (row_id);
      else
	return 0;
    }
  else
    wanted_id = (int64) (ptrlong) row_id;
  *row_id_ret = wanted_id;
  return 1;
}


static int
vvec_hidden_lookup_existing (query_instance_t * qi, vvec_meta_t * meta, caddr_t row_id, dp_addr_t * old_dp_ret)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * root = NULL;
  vvec_node_ref_t next;
  int64 wanted_id;
  if (!meta || !meta->vm_it || !old_dp_ret)
    return 0;
  if (!vvec_row_id_to_i64 (row_id, &wanted_id))
    return 0;

  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);
  vvec_root_read (itc, meta->vm_it, PA_READ, &root);
  next = (vvec_node_ref_t) vvec_meta_ref_i32 (root, VVEC_META_NODE_HEAD);
  while (next)
    {
      buffer_desc_t * node = NULL;
      vvec_node_ref_t cur = next;
      dp_addr_t page_dp = VVEC_NREF_PAGE (cur);
      vvec_page_access (itc, page_dp, PA_READ, &node);
      /* Phase 4: for packed pages, walk the slots; for legacy, walk NEXT_DP. */
      if (vvec_page_role (node) == VVEC_ROLE_PACKED)
	{
	  int slot = VVEC_NREF_SLOT (cur);
	  int nc = vvec_pk_node_count (node);
	  if (slot >= 0 && slot < nc)
	    {
	      db_buf_t cn = vvec_pk_node_ptr (node, slot);
	      if (cn && !vvec_cn_is_deleted (cn) && vvec_cn_d_id (cn) == wanted_id)
		{
		  vvec_page_release (itc, node);
		  vvec_page_release (itc, root);
		  *old_dp_ret = (dp_addr_t) cur;
		  return 1;
		}
	    }
	  /* Advance to next slot or next page. */
	  if (slot + 1 < nc)
	    next = VVEC_NREF_MAKE (page_dp, slot + 1);
	  else
	    next = (vvec_node_ref_t) LONG_REF (node->bd_buffer + VVEC_PK_NEXT_DP) << VVEC_NREF_SLOT_BITS;
	}
      else
	{
	  next = (vvec_node_ref_t) vvec_meta_ref_i32 (node, VVEC_NODE_NEXT_DP);
	  if (!vvec_node_is_deleted (node) && vvec_meta_ref_i64 (node, VVEC_NODE_D_ID) == wanted_id)
	    {
	      vvec_page_release (itc, node);
	      vvec_page_release (itc, root);
	      *old_dp_ret = (dp_addr_t) cur;
	      return 1;
	    }
	}
      vvec_page_release (itc, node);
    }
  vvec_page_release (itc, root);
  return 0;
}


/* Per-batch plan reuse. Before this cache, staging compiled and freed its
   hidden-table statement per row, all under vvec_compile_mtx. Deletes retain a
   separate cached plan for __VEC_INDEX_DELETE_BATCH. */
typedef struct
{
  query_t * vhs_del;
  query_t * vhs_ins;
} vvec_hidden_stmts_t;


/* A NULL slot means the one-off behaviour: compile here, caller frees. */
static query_t *
vvec_hidden_prepare (query_instance_t * qi, query_t ** slot, const char * text)
{
  caddr_t err = NULL;
  query_t * qr;
  if (slot && *slot)
    return *slot;
  qr = vvec_compile_text (qi->qi_client, &err, text);
  if (err)
    sqlr_resignal (err);
  if (slot)
    *slot = qr;
  return qr;
}


static void
vvec_hidden_stmts_free (vvec_hidden_stmts_t * st)
{
  if (st->vhs_del)
    qr_free (st->vhs_del);
  if (st->vhs_ins)
    qr_free (st->vhs_ins);
  st->vhs_del = st->vhs_ins = NULL;
}


static void
vvec_hidden_delete (query_instance_t * qi, vvec_meta_t * meta, caddr_t row_id, vvec_hidden_stmts_t * st)
{
  caddr_t err = NULL;
  char text[1200];
  query_t * qr;
  snprintf (text, sizeof (text), "delete from %s where VE_D_ID = ?", meta->vm_hidden_table);
  qr = vvec_hidden_prepare (qi, st ? &st->vhs_del : NULL, text);
  err = qr_quick_exec (qr, qi->qi_client, "", NULL, 1, ":0", box_copy_tree (row_id), QRP_RAW);
  if (!st)
    qr_free (qr);
  if (SQL_SUCCESS != err)
    sqlr_resignal (err);
}


static void
vvec_hidden_upsert (query_instance_t * qi, vvec_meta_t * meta, caddr_t row_id, caddr_t embedding, const char *source_hash, float magnitude, vvec_hidden_stmts_t * st)
{
  (void) magnitude;
  caddr_t err = NULL;
  char text[1200];
  query_t * qr;
  /* Every hidden-table column is supplied here, so INSERT REPLACING has the
     same final row semantics as DELETE + INSERT while removing one SQL
     execution per vector. At 10M rows that avoids 10M needless deletes. */
  snprintf (text, sizeof (text),
      "insert replacing %s (VE_D_ID, VE_EMBEDDING, SOURCE_HASH, EMBED_STATUS, MODEL_ID, UPDATED_AT) "
      "values (?, ?, ?, 'ready', ?, now ())",
      meta->vm_hidden_table);
  qr = vvec_hidden_prepare (qi, st ? &st->vhs_ins : NULL, text);
  err = qr_quick_exec (qr, qi->qi_client, "", NULL, 4,
      ":0", box_copy_tree (row_id), QRP_RAW,
      ":1", box_copy_tree (embedding), QRP_RAW,
      ":2", source_hash ? (caddr_t) source_hash : NULL, source_hash ? QRP_STR : QRP_RAW,
      ":3", (caddr_t) (ptrlong) meta->vm_model_id, QRP_INT);
  if (!st)
    qr_free (qr);
  if (SQL_SUCCESS != err)
    sqlr_resignal (err);
}


static caddr_t
vvec_hidden_source_hash (query_instance_t * qi, vvec_meta_t * meta, caddr_t row_id)
{
  caddr_t err = NULL;
  local_cursor_t * lc = NULL;
  query_t * qr;
  caddr_t hash = NULL;
  char text[1200];
  snprintf (text, sizeof (text), "select SOURCE_HASH from %s where VE_D_ID = ?", meta->vm_hidden_table);
  qr = vvec_compile_text (qi->qi_client, &err, text);
  if (err)
    sqlr_resignal (err);
  err = qr_quick_exec (qr, qi->qi_client, "", &lc, 1, ":0", box_copy_tree (row_id), QRP_RAW);
  if (SQL_SUCCESS != err)
    {
      qr_free (qr);
      sqlr_resignal (err);
    }
  if (lc && lc_next (lc) && vvec_is_string_box (lc_nth_col (lc, 0)))
    hash = box_copy_tree (lc_nth_col (lc, 0));
  if (lc)
    lc_free (lc);
  qr_free (qr);
  return hash;
}


/* Does this row id still have a committed embedding row?
   A graph node whose row is gone is an *orphan*: the graph insert reached the
   buffer pool but the transaction that owned the row did not commit.  */
/* Re-assert the client's logging mode on the transaction a commit just started.
   A new lt takes lt_replicate from cli_replicate (sqlsrv.c:570), while
   log_enable () only ever set it on the lt that was current when it ran.  So a
   caller who turned logging off for a bulk load gets it back at every commit,
   and log_vec_page () then emits an image per DPF_VEC page until
   TransactionAfterImageLimit aborts the build.  This only restores what the
   client asked for -- it never forces logging off. */
static void
vvec_keep_log_mode (query_instance_t * qi)
{
  if (qi->qi_client && !(qi->qi_client->cli_log_mode & 1))
    qi->qi_trx->lt_replicate = REPL_NO_LOG;
}


/* SLOT, when given, holds a plan compiled once and reused: the orphan sweep asks
   this per graph node, and compiling "select 1 from <hidden> where VE_D_ID = ?"
   nine million times -- each one a full sql_compile_static under
   vvec_compile_mtx -- is why a single search could sit in scn3yyparse for
   hours.  NULL keeps the one-off compile-and-free. */
static int
vvec_hidden_row_exists (query_instance_t * qi, vvec_meta_t * meta, caddr_t row_id,
    query_t ** slot)
{
  caddr_t err = NULL;
  local_cursor_t * lc = NULL;
  query_t * qr;
  char text[1200];
  int found = 0;
  if (slot && *slot)
    qr = *slot;
  else
    {
      snprintf (text, sizeof (text), "select 1 from %s where VE_D_ID = ?", meta->vm_hidden_table);
      qr = vvec_compile_text (qi->qi_client, &err, text);
      if (err)
	{
	  dk_free_tree (err);
	  return 1;   /* cannot tell -- do not drop a hit on a lookup failure */
	}
      if (slot)
	*slot = qr;
    }
  err = qr_quick_exec (qr, qi->qi_client, "", &lc, 1, ":0", box_copy_tree (row_id), QRP_RAW);
  if (SQL_SUCCESS != err)
    {
      if (lc)
	lc_free (lc);
      if (!slot)
	qr_free (qr);
      dk_free_tree (err);
      return 1;
    }
  if (lc && lc_next (lc))
    found = 1;
  if (lc)
    lc_free (lc);
  if (!slot)
    qr_free (qr);
  return found;
}


static caddr_t
vvec_hidden_row_id_by_node (query_instance_t * qi, vvec_meta_t * meta, vvec_node_ref_t nref)
{
  buffer_desc_t * buf = NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  int64 row_id;
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);
  vvec_page_access (itc, VVEC_NREF_PAGE (nref), PA_READ, &buf);
  if (vvec_page_role (buf) == VVEC_ROLE_PACKED)
    {
      db_buf_t cn = vvec_pk_node_ptr (buf, VVEC_NREF_SLOT (nref));
      row_id = cn ? vvec_cn_d_id (cn) : 0;
    }
  else
    row_id = vvec_meta_ref_i64 (buf, VVEC_NODE_D_ID);
  vvec_page_release (itc, buf);
  return box_num (row_id);
}


static void
vvec_hidden_foreach (query_instance_t * qi, const char *hidden_table, local_cursor_t ** lc_ret, query_t ** qr_ret)
{
  caddr_t err = NULL;
  char text[1024];
  snprintf (text, sizeof (text), "select VE_D_ID, VE_EMBEDDING from %s", hidden_table);
  *qr_ret = vvec_compile_text (qi->qi_client, &err, text);
  if (err)
    sqlr_resignal (err);
  err = qr_quick_exec (*qr_ret, qi->qi_client, "", lc_ret, 0);
  if (SQL_SUCCESS != err)
    {
      qr_free (*qr_ret);
      *qr_ret = NULL;
      sqlr_resignal (err);
    }
}


/* ---------------------------------------------------------------------------
   Durability epoch
   ---------------------------------------------------------------------------

   The HNSW graph is a derived structure.  Its pages are dirtied in the buffer
   pool and reach disk only at checkpoint; the transaction log is logical, so
   nothing replays them.  The embeddings in <index>_vec_embeddings, by contrast,
   are ordinary logged rows and recover in full.

   VVEC_META_EPOCH on the root page counts graph mutations and follows the
   checkpoint; DB.DBA.VEC_INDEX_EPOCH.VIE_EPOCH carries the same counter and
   follows the log, because it is written inside the mutating transaction.

     graph_epoch == data_epoch    the two agree
     graph_epoch <  data_epoch    a crash dropped graph mutations the data kept
     graph_epoch >  data_epoch    a rollback (or lost rows) left the graph ahead

   Either inequality means the graph no longer describes the data and must be
   rebuilt from it.  See vvec_epoch_reconcile ().                             */

static int64
vvec_root_epoch_ref (query_instance_t * qi, vvec_meta_t * meta)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * root = NULL;
  int64 epoch;
  if (!meta || !meta->vm_it)
    return 0;
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);
  vvec_root_read (itc, meta->vm_it, PA_READ, &root);
  epoch = vvec_meta_ref_i64 (root, VVEC_META_EPOCH);
  vvec_page_release (itc, root);
  return epoch;
}


/* Mirror the root-page epoch into the catalog.  Deliberately executed on the
   caller's client connection so that it joins the caller's transaction and is
   rolled back with the embedding row it accompanies -- that coupling is the
   whole point of the mechanism, so do not "fix" this by giving it its own
   transaction.  */
static void
vvec_epoch_sync (query_instance_t * qi, vvec_meta_t * meta)
{
  caddr_t err = NULL;
  query_t * qr;
  int64 epoch;
  if (!meta || !meta->vm_key)
    return;
  epoch = vvec_root_epoch_ref (qi, meta);
  qr = vvec_compile_text (qi->qi_client, &err,
      "insert replacing DB.DBA.VEC_INDEX_EPOCH (VIE_KEY_ID, VIE_NAME, VIE_EPOCH, VIE_STATE, VIE_DETAIL, VIE_CHECKED_AT) "
      "values (?, ?, ?, 'ok', null, now ())");
  if (err)
    sqlr_resignal (err);
  err = qr_quick_exec (qr, qi->qi_client, "", NULL, 3,
      ":0", (caddr_t) (ptrlong) meta->vm_key->key_id, QRP_INT,
      ":1", meta->vm_key->key_name ? meta->vm_key->key_name : "", QRP_STR,
      ":2", (caddr_t) (ptrlong) epoch, QRP_INT);
  qr_free (qr);
  if (SQL_SUCCESS != err)
    sqlr_resignal (err);
}


static void vvec_write_epoch_sync (query_instance_t * qi, vvec_meta_t * meta);

/* Resolve the index by name and sync its epoch.  Used by the batch entry
   points, which suppress the per-row sync and settle up once at the end.  */
static void
vvec_epoch_sync_by_name (query_instance_t * qi, const char *func_name, char * index_name)
{
  vvec_meta_t meta;
  vvec_require_key (qi, func_name, index_name, &meta);
  vvec_write_epoch_sync (qi, &meta);
}


/* Health of a vector index's graph, as established by epoch reconciliation. */
#define VVEC_HEALTH_UNCHECKED 0
#define VVEC_HEALTH_OK 1
#define VVEC_HEALTH_NEEDS_REBUILD 2

/* key_id -> VVEC_HEALTH_*.  Reconciliation is meaningful exactly once per
   index per server start, because that is when a lost checkpoint shows up, so
   the result is cached here for the life of the process.  Cleared for an index
   by a successful rebuild.  */
static dk_hash_t * vvec_health_hash = NULL;
static dk_mutex_t * vvec_health_mtx = NULL;


static int
vvec_health_cached (oid_t key_id)
{
  int state = VVEC_HEALTH_UNCHECKED;
  if (!vvec_health_hash)
    return VVEC_HEALTH_UNCHECKED;
  mutex_enter (vvec_health_mtx);
  state = (int) (ptrlong) gethash (DP_ADDR2VOID (key_id), vvec_health_hash);
  mutex_leave (vvec_health_mtx);
  return state;
}


static void
vvec_health_set (oid_t key_id, int state)
{
  if (!vvec_health_hash)
    return;
  mutex_enter (vvec_health_mtx);
  sethash (DP_ADDR2VOID (key_id), vvec_health_hash, (void *) (ptrlong) state);
  mutex_leave (vvec_health_mtx);
}


/* Does the catalog record this index as needing a rebuild?  The persisted half
   of the verdict: after a restart the per-process cache knows nothing until the
   index is next reconciled, but VIE_STATE still says what the last check found. */
static int
vvec_catalog_needs_rebuild (query_instance_t * qi, vvec_meta_t * meta)
{
  caddr_t err = NULL;
  local_cursor_t * lc = NULL;
  query_t * qr;
  int flagged = 0;
  if (!sch_name_to_table (wi_inst.wi_schema, "DB.DBA.VEC_INDEX_EPOCH"))
    return 0;
  qr = vvec_compile_text (qi->qi_client, &err,
      "select 1 from DB.DBA.VEC_INDEX_EPOCH where VIE_KEY_ID = ? and VIE_STATE = 'needs_rebuild'");
  if (err)
    {
      dk_free_tree (err);
      return 0;
    }
  err = qr_quick_exec (qr, qi->qi_client, "", &lc, 1,
      ":0", (caddr_t) (ptrlong) meta->vm_key->key_id, QRP_INT);
  if (SQL_SUCCESS == err && lc && lc_next (lc))
    flagged = 1;
  if (lc)
    lc_free (lc);
  qr_free (qr);
  dk_free_tree (err);
  return flagged;
}


/* The epoch sync an ordinary graph write ends with -- insert, delete, their
   batch forms.  It mirrors the root page's epoch into the catalog, which makes
   the pair agree; so on an index reconciliation has condemned it must not run,
   or the next check -- a recheck, or the next server start -- declares the
   divergent graph healthy.  Only a rebuild, or reconciliation's own repair,
   brings the pair back together; they call vvec_epoch_sync () directly.

   The cached verdict answers in the steady state.  Before this process has
   reconciled the index -- straight after a restart -- the catalog's VIE_STATE
   stands in for it.  Nothing here reconciles: a write is not the place to walk
   the graph. */
static void
vvec_write_epoch_sync (query_instance_t * qi, vvec_meta_t * meta)
{
  int state;
  if (!meta || !meta->vm_key)
    return;
  state = vvec_health_cached (meta->vm_key->key_id);
  if (VVEC_HEALTH_NEEDS_REBUILD == state)
    return;
  if (VVEC_HEALTH_UNCHECKED == state && vvec_catalog_needs_rebuild (qi, meta))
    return;
  vvec_epoch_sync (qi, meta);
}


/* Per-index writer serialization.
 *
 * One HNSW insert touches several pages: it reads and rewrites the neighbour
 * lists of existing nodes, adds reciprocal backlinks, and read-modify-writes the
 * root-page entry point / max layer / node counters.  The per-page latches taken
 * by vvec_page_access protect one page at a time -- they do NOT make that
 * multi-page sequence atomic.  Two writers on the same index would otherwise
 * interleave their read-modify-writes and could lose neighbour edges (last writer
 * wins on a shared node page), leave the entry point pointing at a node from a
 * different layer assignment, or corrupt ACTIVE_NODES / TOTAL_NODES.
 *
 * A per-index mutex held across the whole insert/delete/rebuild closes that gap.
 * Readers stay concurrent: search takes short-lived per-page read latches (so it
 * never sees a torn page), verifies every hit against the hidden table, and holds
 * the graph read gate below so rebuild cannot free a page named by an nref it has
 * retained.  It therefore needs no writer mutex.
 *
 * The mutex is keyed by key_id and allocated lazily, mirroring vvec_health_hash.
 * Ordering rule: it is always acquired BEFORE any page latch and released AFTER,
 * never the reverse, so it cannot invert lock order with the buffer manager.
 * Because the mutation code can longjmp out of a page-access or embedded-SQL
 * failure, every caller releases it on the error-unwind path (QR_RESET_CODE).
 * The per-index mutexes are never freed (an index's key_id may be reused after a
 * drop/recreate, and the count is bounded by the number of distinct indexes),
 * exactly like the health hash.
 */
static dk_mutex_t *
vvec_writer_lock (index_tree_t * it)
{
  if (!it)
    return NULL;
  mutex_enter (&it->it_vvec.vt_writer_mtx);
  return &it->it_vvec.vt_writer_mtx;
}


static void
vvec_writer_unlock (dk_mutex_t * mtx)
{
  if (mtx)
    mutex_leave (mtx);
}


/* A page latch protects one graph page, not a reference copied out of it.  A
 * search releases each page before following the next nref, while rebuild
 * releases every old graph page.  Without a graph-lifetime barrier rebuild can
 * therefore free the next page between those two operations.  Keep searches
 * concurrent with each other and with ordinary inserts/deletes, but exclude a
 * rebuild for the lifetime of every reference a graph reader retains.
 *
 * Lock order for rebuild is graph write lock -> writer mutex -> page latch.
 * The gate belongs to the index_tree_t whose cross-page references it protects;
 * it is allocated and released with that tree. */


#define vvec_graph_gate_get(it) ((it) ? (it)->it_vvec.vt_graph_rwlock : NULL)


static rwlock_t *
vvec_graph_read_lock (index_tree_t * it)
{
  rwlock_t * gate = vvec_graph_gate_get (it);
  if (gate)
    rwlock_rdlock (gate);
  return gate;
}


static rwlock_t *
vvec_graph_write_lock (index_tree_t * it)
{
  rwlock_t * gate = vvec_graph_gate_get (it);
  if (gate)
    rwlock_wrlock (gate);
  return gate;
}


static void
vvec_graph_unlock (rwlock_t * gate)
{
  if (gate)
    rwlock_unlock (gate);
}


/* ======================================================================= *
 *  perf phase 2: in-memory compute-ready float32 vector arena
 *
 *  A per-index contiguous native-float32 mirror of the node vectors, keyed by page
 *  address (dp). During a build/insert the HNSW traversal reads each neighbor's
 *  vector from the arena instead of latching that neighbor's page and byte-swapping
 *  the stored vector -- removing the dominant per-neighbor buffer-manager cost
 *  (gethash + page_wait_access) and the big-endian deswizzle found in profiling
 *  (perf/01).
 *
 *  SAFETY.  The arena is reached only through vvec_meta_t.vm_arena, which is set
 *  ONLY on the insert path (vvec_insert_graph) and left NULL for concurrent external
 *  searches. Writers on one index are serialized by the per-index writer mutex
 *  (prompt 06), so at most one thread ever touches a given arena at a time -- the hot
 *  path needs no internal locking. The only shared structure is the key_id->arena
 *  map, guarded by vvec_arena_hash_mtx for lookup/creation/removal.
 *
 *  INVARIANT.  A dp present in the arena and not va_deleted is a live node whose
 *  stored vector is immutable (updates are delete+insert, never in place). Deletes
 *  and reaps flip va_deleted (vvec_mark_node_deleted_1); rebuild and drop free the
 *  arena (its dps no longer map to the same nodes). A page reused after a reap is
 *  re-registered by vvec_arena_add, which overwrites the stale mapping.
 *
 *  Storage is chunked (fixed-size blocks) so a large arena never needs one giant
 *  allocation and existing vectors never move.
 * ======================================================================= */

#define VVEC_ARENA_SHIFT 13
#define VVEC_ARENA_BLOCK (1 << VVEC_ARENA_SHIFT)      /* vectors per block */
#define VVEC_ARENA_MASK  (VVEC_ARENA_BLOCK - 1)

typedef struct vvec_arena_s
{
  int va_dim;                    /* stored (post-reduce) dimension */
  int va_count;                  /* number of slots assigned */
  int va_nblocks;                /* allocated block-pointer / mag / deleted capacity (in blocks) */
  dk_hash_t * va_dp2slot;        /* dp -> slot + 1 (0 == absent) */
  float ** va_blocks;            /* va_nblocks pointers, each VVEC_ARENA_BLOCK*va_dim floats */
  float * va_mag;                /* va_nblocks*VVEC_ARENA_BLOCK magnitudes */
  unsigned char * va_deleted;    /* va_nblocks*VVEC_ARENA_BLOCK flags */
} vvec_arena_t;

static dk_hash_t * vvec_arena_hash = NULL;        /* key_id -> vvec_arena_t * */
static dk_mutex_t * vvec_arena_hash_mtx = NULL;

static float *
vvec_arena_slot_vec (vvec_arena_t * a, int slot)
{
  return a->va_blocks[slot >> VVEC_ARENA_SHIFT] + (size_t) (slot & VVEC_ARENA_MASK) * a->va_dim;
}

/* Ensure block storage exists for slot index. */
static void
vvec_arena_ensure_slot (vvec_arena_t * a, int slot)
{
  int b = slot >> VVEC_ARENA_SHIFT;
  if (b >= a->va_nblocks)
    {
      int nb = a->va_nblocks ? a->va_nblocks * 2 : 8;
      float ** blocks = (float **) dk_alloc (nb * sizeof (float *));
      float * mag = (float *) dk_alloc ((size_t) nb * VVEC_ARENA_BLOCK * sizeof (float));
      unsigned char * del = (unsigned char *) dk_alloc ((size_t) nb * VVEC_ARENA_BLOCK);
      memset (blocks, 0, nb * sizeof (float *));
      if (a->va_nblocks)
	{
	  memcpy (blocks, a->va_blocks, a->va_nblocks * sizeof (float *));
	  memcpy (mag, a->va_mag, (size_t) a->va_nblocks * VVEC_ARENA_BLOCK * sizeof (float));
	  memcpy (del, a->va_deleted, (size_t) a->va_nblocks * VVEC_ARENA_BLOCK);
	  dk_free ((caddr_t) a->va_blocks, a->va_nblocks * sizeof (float *));
	  dk_free ((caddr_t) a->va_mag, (size_t) a->va_nblocks * VVEC_ARENA_BLOCK * sizeof (float));
	  dk_free ((caddr_t) a->va_deleted, (size_t) a->va_nblocks * VVEC_ARENA_BLOCK);
	}
      a->va_blocks = blocks;
      a->va_mag = mag;
      a->va_deleted = del;
      a->va_nblocks = nb;
    }
  if (!a->va_blocks[b])
    a->va_blocks[b] = (float *) dk_alloc ((size_t) VVEC_ARENA_BLOCK * a->va_dim * sizeof (float));
}

/* Register (or refresh) dp's native float32 vector + magnitude. Idempotent: a dp
   already present (e.g. a page reused after reap) is overwritten and un-deleted. */
static void
vvec_arena_add (vvec_arena_t * a, dp_addr_t dp, const float * vec, float mag)
{
  ptrlong existing;
  int slot;
  if (!a)
    return;
  existing = (ptrlong) gethash (DP_ADDR2VOID (dp), a->va_dp2slot);
  if (existing)
    slot = (int) existing - 1;
  else
    {
      slot = a->va_count;
      vvec_arena_ensure_slot (a, slot);
      a->va_count++;
      sethash (DP_ADDR2VOID (dp), a->va_dp2slot, (void *) (ptrlong) (slot + 1));
    }
  memcpy (vvec_arena_slot_vec (a, slot), vec, (size_t) a->va_dim * sizeof (float));
  a->va_mag[slot] = mag;
  a->va_deleted[slot] = 0;
}

/* Distance from an arena-resident node to the query. Returns 1 and sets *out if dp
   is present (VVEC_DISTANCE_INF for a deleted node); returns 0 on a miss. */
static int
vvec_arena_distance (vvec_arena_t * a, dp_addr_t dp, const float * query, float query_mag,
    int metric, int dim, float * out)
{
  ptrlong e;
  int slot;
  const float * v;
  float mag;
  if (!a)
    return 0;
  e = (ptrlong) gethash (DP_ADDR2VOID (dp), a->va_dp2slot);
  if (!e)
    return 0;
  slot = (int) e - 1;
  if (a->va_deleted[slot])
    { *out = VVEC_DISTANCE_INF; return 1; }
  v = vvec_arena_slot_vec (a, slot);
  mag = a->va_mag[slot];
  if (VVEC_METRIC_L2 == metric)
    *out = (float) sqrt ((double) vvec_l2sqr_f32 (v, query, dim));
  else if (VVEC_METRIC_L1 == metric)
    *out = vvec_l1_f32 (v, query, dim);
  else
    {
      double dot = (double) vvec_ip_f32 (v, query, dim);
      *out = (!mag || !query_mag) ? 2.0f : (float) (1.0 - (dot / (((double) mag) * ((double) query_mag))));
    }
  return 1;
}

/* Get or lazily create the arena for an index. Returns NULL if the stored dimension
   changed (a drop/recreate reusing the key_id) so the caller falls back to pages
   until the stale arena is dropped. */
static vvec_arena_t *
vvec_arena_for_key (oid_t key_id, int dim)
{
  vvec_arena_t * a;
  if (!vvec_arena_hash || dim <= 0)
    return NULL;
  if (getenv ("VVEC_NO_ARENA"))     /* benchmark A/B toggle: disable the arena */
    return NULL;
  mutex_enter (vvec_arena_hash_mtx);
  a = (vvec_arena_t *) gethash (DP_ADDR2VOID (key_id), vvec_arena_hash);
  if (!a)
    {
      a = (vvec_arena_t *) dk_alloc (sizeof (vvec_arena_t));
      memset (a, 0, sizeof (vvec_arena_t));
      a->va_dim = dim;
      a->va_dp2slot = hash_table_allocate (4096);
      sethash (DP_ADDR2VOID (key_id), vvec_arena_hash, (void *) a);
    }
  mutex_leave (vvec_arena_hash_mtx);
  if (a->va_dim != dim)
    return NULL;
  return a;
}

static vvec_arena_t *
vvec_arena_peek (oid_t key_id)
{
  vvec_arena_t * a;
  if (!vvec_arena_hash)
    return NULL;
  mutex_enter (vvec_arena_hash_mtx);
  a = (vvec_arena_t *) gethash (DP_ADDR2VOID (key_id), vvec_arena_hash);
  mutex_leave (vvec_arena_hash_mtx);
  return a;
}

/* Mark dp deleted or live in the arena if present (called from the delete/reap
   choke point and its undo, under the writer lock). */
static void
vvec_arena_mark_deleted (oid_t key_id, dp_addr_t dp, int deleted)
{
  vvec_arena_t * a = vvec_arena_peek (key_id);
  ptrlong e;
  if (!a)
    return;
  e = (ptrlong) gethash (DP_ADDR2VOID (dp), a->va_dp2slot);
  if (e)
    a->va_deleted[(int) e - 1] = deleted ? 1 : 0;
}

/* Free and unregister the arena for an index (rebuild changes every dp; drop removes
   the index). Safe under the writer lock: external searches never hold a reference. */
static void
vvec_arena_drop (oid_t key_id)
{
  vvec_arena_t * a;
  int b;
  if (!vvec_arena_hash)
    return;
  mutex_enter (vvec_arena_hash_mtx);
  a = (vvec_arena_t *) gethash (DP_ADDR2VOID (key_id), vvec_arena_hash);
  if (a)
    remhash (DP_ADDR2VOID (key_id), vvec_arena_hash);
  mutex_leave (vvec_arena_hash_mtx);
  if (!a)
    return;
  for (b = 0; b < a->va_nblocks; b++)
    if (a->va_blocks[b])
      dk_free ((caddr_t) a->va_blocks[b], (size_t) VVEC_ARENA_BLOCK * a->va_dim * sizeof (float));
  if (a->va_blocks)
    dk_free ((caddr_t) a->va_blocks, a->va_nblocks * sizeof (float *));
  if (a->va_mag)
    dk_free ((caddr_t) a->va_mag, (size_t) a->va_nblocks * VVEC_ARENA_BLOCK * sizeof (float));
  if (a->va_deleted)
    dk_free ((caddr_t) a->va_deleted, (size_t) a->va_nblocks * VVEC_ARENA_BLOCK);
  if (a->va_dp2slot)
    hash_table_free (a->va_dp2slot);
  dk_free ((caddr_t) a, sizeof (vvec_arena_t));
}


/* Read the last committed epoch for this index.  Returns 0 and sets *found_ret
   to 0 when the catalog has no row -- either the index predates the epoch
   mechanism or it has never been written to.  Neither is a divergence.  */
static int64
vvec_catalog_epoch_ref (query_instance_t * qi, vvec_meta_t * meta, int * found_ret)
{
  caddr_t err = NULL;
  local_cursor_t * lc = NULL;
  query_t * qr;
  int64 epoch = 0;
  *found_ret = 0;
  if (!sch_name_to_table (wi_inst.wi_schema, "DB.DBA.VEC_INDEX_EPOCH"))
    return 0;
  qr = vvec_compile_text (qi->qi_client, &err,
      "select VIE_EPOCH from DB.DBA.VEC_INDEX_EPOCH where VIE_KEY_ID = ?");
  if (err)
    {
      dk_free_tree (err);
      return 0;
    }
  err = qr_quick_exec (qr, qi->qi_client, "", &lc, 1,
      ":0", (caddr_t) (ptrlong) meta->vm_key->key_id, QRP_INT);
  if (SQL_SUCCESS != err)
    {
      if (lc)
	lc_free (lc);
      qr_free (qr);
      dk_free_tree (err);
      return 0;
    }
  if (lc && lc_next (lc))
    {
      caddr_t val = lc_nth_col (lc, 0);
      if (val && DV_DB_NULL != DV_TYPE_OF (val))
	{
	  epoch = unbox (val);
	  *found_ret = 1;
	}
    }
  if (lc)
    lc_free (lc);
  qr_free (qr);
  return epoch;
}


/* Record that the index reconciled clean, without touching the epoch itself. */
static void
vvec_catalog_mark_ok (query_instance_t * qi, vvec_meta_t * meta)
{
  caddr_t err = NULL;
  query_t * qr;
  if (!sch_name_to_table (wi_inst.wi_schema, "DB.DBA.VEC_INDEX_EPOCH"))
    return;
  qr = vvec_compile_text (qi->qi_client, &err,
      "update DB.DBA.VEC_INDEX_EPOCH set VIE_STATE = 'ok', VIE_DETAIL = null, VIE_CHECKED_AT = now () where VIE_KEY_ID = ?");
  if (err)
    {
      dk_free_tree (err);
      return;
    }
  err = qr_quick_exec (qr, qi->qi_client, "", NULL, 1,
      ":0", (caddr_t) (ptrlong) meta->vm_key->key_id, QRP_INT);
  qr_free (qr);
  dk_free_tree (err);
}


static void
vvec_catalog_mark_needs_rebuild (query_instance_t * qi, vvec_meta_t * meta, const char *detail)
{
  caddr_t err = NULL;
  query_t * qr;
  if (!sch_name_to_table (wi_inst.wi_schema, "DB.DBA.VEC_INDEX_EPOCH"))
    return;
  /* State and detail only -- never VIE_EPOCH.  VIE_EPOCH is the data's epoch,
     the committed mirror every reconciliation compares the graph against.
     Writing the graph's epoch into it here made the pair agree, so the next
     check -- a recheck, or the next server start -- declared the divergent
     graph healthy and served searches from it: the verdict lasted exactly as
     long as the per-process cache.  The row exists: reconciliation returns
     before condemning anything that has no catalog row. */
  qr = vvec_compile_text (qi->qi_client, &err,
      "update DB.DBA.VEC_INDEX_EPOCH set VIE_STATE = 'needs_rebuild', VIE_DETAIL = ?, VIE_CHECKED_AT = now () "
      "where VIE_KEY_ID = ?");
  if (err)
    {
      dk_free_tree (err);
      return;
    }
  err = qr_quick_exec (qr, qi->qi_client, "", NULL, 2,
      ":0", (caddr_t) detail, QRP_STR,
      ":1", (caddr_t) (ptrlong) meta->vm_key->key_id, QRP_INT);
  qr_free (qr);
  dk_free_tree (err);
}


/* Sweep the node chain and retire every node whose embedding row is gone.
 *
 * Only worth running when the graph is *ahead* of the data, which is the
 * rollback signature: some insert reached the buffer pool but its row never
 * committed.  Those nodes are removable, so a rolled-back insert should not
 * cost a full rebuild.
 *
 * Page latches are released before any SQL runs -- the candidate list is
 * collected first, then checked -- because running a query with a page latch
 * held is a deadlock waiting to happen.
 */
static int
vvec_sweep_orphans_1 (query_instance_t * qi, vvec_meta_t * meta)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * root = NULL;
  vvec_node_ref_t next;
  dk_set_t candidates = NULL;
  query_t * exists_qr = NULL;
  int reaped = 0;
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);
  vvec_root_read (itc, meta->vm_it, PA_READ, &root);
  next = (vvec_node_ref_t) vvec_meta_ref_i32 (root, VVEC_META_NODE_HEAD);
  while (next)
    {
      buffer_desc_t * node = NULL;
      vvec_node_ref_t cur = next;
      dp_addr_t page_dp = VVEC_NREF_PAGE (cur);
      vvec_page_access (itc, page_dp, PA_READ, &node);
      if (vvec_page_role (node) == VVEC_ROLE_PACKED)
	{
	  int slot = VVEC_NREF_SLOT (cur);
	  int nc = vvec_pk_node_count (node);
	  if (slot >= 0 && slot < nc)
	    {
	      db_buf_t cn = vvec_pk_node_ptr (node, slot);
	      if (cn && !vvec_cn_is_deleted (cn))
		{
		  dk_set_push (&candidates, (void *) (ptrlong) cur);
		  dk_set_push (&candidates, (void *) (ptrlong) vvec_cn_d_id (cn));
		}
	    }
	  if (slot + 1 < nc)
	    next = VVEC_NREF_MAKE (page_dp, slot + 1);
	  else
	    next = (vvec_node_ref_t) LONG_REF (node->bd_buffer + VVEC_PK_NEXT_DP) << VVEC_NREF_SLOT_BITS;
	}
      else
	{
	  next = (vvec_node_ref_t) vvec_meta_ref_i32 (node, VVEC_NODE_NEXT_DP);
	  if (!vvec_node_is_deleted (node))
	    {
	      dk_set_push (&candidates, (void *) (ptrlong) cur);
	      dk_set_push (&candidates, (void *) (ptrlong) vvec_meta_ref_i64 (node, VVEC_NODE_D_ID));
	    }
	}
      vvec_page_release (itc, node);
    }
  vvec_page_release (itc, root);
  while (candidates)
    {
      int64 d_id = (int64) (ptrlong) dk_set_pop (&candidates);
      vvec_node_ref_t nref = (vvec_node_ref_t) (ptrlong) dk_set_pop (&candidates);
      caddr_t row_id = box_num (d_id);
      if (!vvec_hidden_row_exists (qi, meta, row_id, &exists_qr))
	{
	  vvec_reap_orphan_node (qi, meta, nref, row_id);
	  reaped++;
	}
      dk_free_tree (row_id);
    }
  if (exists_qr)
    qr_free (exists_qr);
  return reaped;
}


/* The sweep first records nrefs and only then revisits them to retire orphans.
 * Protect that complete lifetime: otherwise a concurrent rebuild can recycle a
 * recorded dp before the second pass and the sweep can delete a node in the new
 * graph. */
static int
vvec_sweep_orphans (query_instance_t * qi, vvec_meta_t * meta)
{
  rwlock_t * gate = vvec_graph_read_lock (meta->vm_it);
  int reaped = 0;
  QR_RESET_CTX_T (qi->qi_thread)
    {
      reaped = vvec_sweep_orphans_1 (qi, meta);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_graph_unlock (gate);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_graph_unlock (gate);
  return reaped;
}


/* Indexes whose redo could not be applied in full -- see vvec_replay_page ().
   Recovery runs single-threaded out of log_init (), before the server listens,
   so this needs no lock while it is being filled; the reads afterwards are of
   a set that never changes again.  It is deliberately not the health hash:
   that is initialised elsewhere in srv_global_init () and may not exist yet
   when replay runs, and a mark that silently went nowhere is exactly the
   failure this is guarding against. */
static dk_hash_t * vvec_replay_condemned = NULL;

void
vvec_replay_condemn (key_id_t key_id)
{
  dbe_key_t * key;
  if (!vvec_replay_condemned)
    vvec_replay_condemned = hash_table_allocate (11);
  if (gethash (DP_ADDR2VOID (key_id), vvec_replay_condemned))
    return;
  sethash (DP_ADDR2VOID (key_id), vvec_replay_condemned, (void *) (ptrlong) 1);
  /* Forget any verdict already reached about this index.  vvec_epoch_reconcile ()
     returns a cached health without looking further, so an index that was used
     -- and found healthy -- before a DBA ran replay () would never consult the
     mark below.  A no-op during roll forward, where nothing has been checked yet
     and the hash may not exist; vvec_health_set () guards for that. */
  vvec_health_set (key_id, VVEC_HEALTH_UNCHECKED);
  /* Once per index, not per record: a recovery that skips one record usually
     skips many, and this must not flood.  Roll forward has no client to receive
     it -- sql_warning_add () drops warnings while the server is not up -- so the
     server log is what an operator reads there.  It is raised for replay ()
     called from SQL, which does have a client, so that a skipped record is never
     silent on either path. */
  key = sch_id_to_key (wi_inst.wi_schema, key_id);
  sqlr_warning ("01V01", "VEC93",
      "Vector index %s lost part of its graph in redo and will be rebuilt from the stored embeddings",
      key && key->key_name ? key->key_name : "(unnamed)");
}

/* Did this index lose redo in this process's recovery?  Does not clear the
   mark -- for callers that only want to report, not to act on it. */
static int
vvec_replay_condemned_p (key_id_t key_id)
{
  return vvec_replay_condemned
      && NULL != gethash (DP_ADDR2VOID (key_id), vvec_replay_condemned);
}

/* True once, for an index that lost redo in this process's recovery.  Cleared
   on the way out so the rebuild it triggers is attempted once rather than on
   every health check: if that rebuild fails, the ordinary epoch comparison and
   the catalog's needs_rebuild flag carry it from there. */
static int
vvec_replay_was_condemned (key_id_t key_id)
{
  if (!vvec_replay_condemned_p (key_id))
    return 0;
  remhash (DP_ADDR2VOID (key_id), vvec_replay_condemned);
  return 1;
}


/* A dropped index's key_id goes to the next key created (qi_new_key_id takes the lowest free
   one), so nothing held by key_id may outlive the index: not the epoch row, not a cached verdict. */
static void
vvec_forget_key_id (query_instance_t * qi, key_id_t key_id)
{
  caddr_t err = NULL;
  query_t * qr;
  vvec_health_set (key_id, VVEC_HEALTH_UNCHECKED);
  if (vvec_replay_condemned)
    remhash (DP_ADDR2VOID (key_id), vvec_replay_condemned);
  if (!sch_name_to_table (wi_inst.wi_schema, "DB.DBA.VEC_INDEX_EPOCH"))
    return;
  qr = vvec_compile_text (qi->qi_client, &err, "delete from DB.DBA.VEC_INDEX_EPOCH where VIE_KEY_ID = ?");
  if (err)
    sqlr_resignal (err);
  err = qr_quick_exec (qr, qi->qi_client, "", NULL, 1, ":0", (caddr_t) (ptrlong) key_id, QRP_INT);
  qr_free (qr);
  if (SQL_SUCCESS != err)
    sqlr_resignal (err);
}


/* Compare what the graph durably knows against what the data durably knows.
   Runs once per index per server start; the answer is cached.  */
static int
vvec_epoch_reconcile (query_instance_t * qi, vvec_meta_t * meta)
{
  int64 graph_epoch;
  int64 data_epoch;
  int found = 0;
  int state;
  char detail[512];
  if (!meta || !meta->vm_key || !meta->vm_it)
    return VVEC_HEALTH_OK;
  state = vvec_health_cached (meta->vm_key->key_id);
  if (VVEC_HEALTH_UNCHECKED != state)
    return state;
  graph_epoch = vvec_root_epoch_ref (qi, meta);
  /* Recovery could not apply part of this index's redo, so the graph is
     missing whatever those records carried.  The epochs cannot be trusted to
     say so -- the root page's own epoch travels in a LOG_VEC_PAGE record like
     any other, so a graph that lost node pages can still come back claiming to
     be current.  Force the data_epoch comparison into the rebuild branch
     rather than leaving it to a number the same failure may have falsified. */
  if (vvec_replay_was_condemned (meta->vm_key->key_id))
    {
      log_error ("Vector index %s: recovery could not replay part of its graph. "
	  "Rebuilding it from the stored embeddings.",
	  meta->vm_key->key_name ? meta->vm_key->key_name : "<unknown>");
      graph_epoch = -1;
    }
  data_epoch = vvec_catalog_epoch_ref (qi, meta, &found);
  if (!found)
    {
      /* No catalog row.  An index created before this mechanism existed, or one
         that has never been written to.  Nothing to compare against, so do not
         cry wolf -- the first mutation will establish the pair.  */
      vvec_health_set (meta->vm_key->key_id, VVEC_HEALTH_OK);
      return VVEC_HEALTH_OK;
    }
  if (graph_epoch == data_epoch)
    {
      vvec_health_set (meta->vm_key->key_id, VVEC_HEALTH_OK);
      return VVEC_HEALTH_OK;
    }
  if (graph_epoch > data_epoch)
    {
      /* The graph is ahead: uncommitted inserts left orphan nodes behind.
         Those are removable, so try repairing in place before condemning the
         index -- a single rolled-back insert should not cost a full rebuild.
         Reaping decrements the epoch per node, so if every excess mutation was
         an orphan the pair re-converges here.  */
      int reaped = vvec_sweep_orphans (qi, meta);
      if (reaped)
	{
	  graph_epoch = vvec_root_epoch_ref (qi, meta);
	  log_error ("Vector index %s: retired %d orphan node(s) left by rolled-back transaction(s); "
	      "graph epoch now %ld, data epoch %ld.",
	      meta->vm_key->key_name ? meta->vm_key->key_name : "<unknown>",
	      reaped, (long) graph_epoch, (long) data_epoch);
	  if (graph_epoch == data_epoch)
	    {
	      vvec_catalog_mark_ok (qi, meta);
	      vvec_health_set (meta->vm_key->key_id, VVEC_HEALTH_OK);
	      return VVEC_HEALTH_OK;
	    }
	}
    }
  if (graph_epoch < data_epoch)
    {
      /* The crash signature, and the one case that is repairable without an
         operator.  Everything the graph is missing is sitting in the hidden
         embeddings table: that is an ordinary logged table, so roll-forward
         brought it back along with the catalog epoch, while the graph pages
         stopped at the last checkpoint.  Rebuild from it rather than condemning
         the index and making a human run __VEC_INDEX_REBUILD by hand -- a
         database that comes back up answering no vector query at all has lost
         user data in every sense that matters, even though the bytes needed to
         reconstruct it are all present.

         This is the mirror of the graph-ahead branch above, which already
         repairs in place by sweeping orphans.  Only the ahead direction had
         been implemented.

         A whole rebuild rather than just the missing rows: the bulk builder is
         an order of magnitude faster than inserting nodes one at a time, so for
         anything but a trivial delta it wins outright, and reusing a path the
         suite already covers beats hand-rolling a second one inside recovery.
         Identifying the delta at all would need a full graph walk first --
         vvec_hidden_lookup_existing () is O(N) per probe -- so the saving is
         smaller than it looks.  If a measured crash delta ever makes the
         difference matter, a delta path can be added behind this decision
         without changing the contract.

         Fail closed while it runs: mark the index unhealthy first, so a
         concurrent reader arriving mid-repair is refused by
         vvec_require_healthy () instead of being served from a half-built
         graph.  vvec_rebuild_impl () sets the health back to OK itself on
         success.  */
      caddr_t rb_count = NULL;
      caddr_t rb_err = NULL;
      log_error ("Vector index %s: the graph persisted %ld mutation(s) but %ld were committed -- "
	  "an unclean shutdown discarded graph pages that had not reached a checkpoint. "
	  "Rebuilding it automatically from the stored embeddings.",
	  meta->vm_key->key_name ? meta->vm_key->key_name : "<unknown>",
	  (long) graph_epoch, (long) data_epoch);
      vvec_health_set (meta->vm_key->key_id, VVEC_HEALTH_NEEDS_REBUILD);
      /* Catch a failing rebuild rather than letting it unwind.  This runs under
         vvec_require_healthy (), which exists so that read paths get one
         predictable refusal; letting an arbitrary rebuild error escape from
         inside a SELECT would replace VEC80 -- which names the index and says
         what to do -- with whatever went wrong three layers down.  Catching it
         also keeps the condemn path below reachable: vvec_rebuild_impl ()
         returns a row count and signals failure only by resignalling, and
         vvec_epoch_sync () force-writes the catalog epoch to the root's, so a
         rebuild that returns at all has converged by construction.  */
      QR_RESET_CTX_T (qi->qi_thread)
	{
	  rb_count = vvec_rebuild_impl (qi, "vvec_epoch_reconcile",
	      meta->vm_key->key_name, VVEC_REBUILD_UNSET, 0);
	}
      QR_RESET_CODE
	{
	  rb_err = thr_get_error_code (qi->qi_thread);
	  POP_QR_RESET;
	}
      END_QR_RESET;
      dk_free_tree (rb_count);
      if (rb_err)
	{
	  log_error ("Vector index %s: the automatic rebuild failed (%s: %s). "
	      "Leaving the index unusable rather than serving a partial graph.",
	      meta->vm_key->key_name ? meta->vm_key->key_name : "<unknown>",
	      ERR_STATE (rb_err) ? ERR_STATE (rb_err) : "?",
	      ERR_MESSAGE (rb_err) ? ERR_MESSAGE (rb_err) : "no detail");
	  dk_free_tree (rb_err);
	}
      /* Ask the health the rebuild recorded, rather than re-deriving a verdict
         here.  vvec_rebuild_impl () builds its own meta and replaces the graph,
         so reading the root epoch through this function's meta reports the
         pre-rebuild value and would condemn an index that is in fact
         repaired.  */
      else if (VVEC_HEALTH_OK == vvec_health_cached (meta->vm_key->key_id))
	{
	  log_error ("Vector index %s: rebuilt automatically after an unclean shutdown; "
	      "the graph describes the data again.",
	      meta->vm_key->key_name ? meta->vm_key->key_name : "<unknown>");
	  return VVEC_HEALTH_OK;
	}
      /* The repair did not take.  Fall through and condemn: degrading to the
         previous behaviour is acceptable, serving a half-repaired graph is
         not.  */
    }
  if (graph_epoch < data_epoch)
    snprintf (detail, sizeof (detail),
	"Graph is behind the data: the HNSW graph persisted %ld mutation(s) but %ld were committed. "
	"An unclean shutdown discarded graph pages that had not reached a checkpoint. "
	"An automatic rebuild was attempted and did not converge.",
	(long) graph_epoch, (long) data_epoch);
  else
    snprintf (detail, sizeof (detail),
	"Graph is ahead of the data: the HNSW graph persisted %ld mutation(s) but only %ld were committed. "
	"A rolled-back transaction left nodes in the graph with no backing row.",
	(long) graph_epoch, (long) data_epoch);
  log_error ("Vector index %s needs a rebuild. %s Searches on it will fail until "
      "__VEC_INDEX_REBUILD is run.",
      meta->vm_key->key_name ? meta->vm_key->key_name : "<unknown>", detail);
  vvec_catalog_mark_needs_rebuild (qi, meta, detail);
  vvec_health_set (meta->vm_key->key_id, VVEC_HEALTH_NEEDS_REBUILD);
  return VVEC_HEALTH_NEEDS_REBUILD;
}


/* Gate for read paths.  A divergent graph must never answer a query: a partial
   or phantom nearest-neighbour result is indistinguishable from a correct one
   to the caller, which is exactly what makes it dangerous.  */
static void
vvec_require_healthy (query_instance_t * qi, vvec_meta_t * meta, const char *func_name)
{
  if (VVEC_HEALTH_NEEDS_REBUILD != vvec_epoch_reconcile (qi, meta))
    return;
  sqlr_new_error ("42000", "VEC80",
      "%s: vector index %s is inconsistent with its stored embeddings and cannot serve searches. "
      "Rebuild it with __VEC_INDEX_REBUILD ('%s'). "
      "See DB.DBA.VEC_INDEX_EPOCH for details.",
      func_name, meta->vm_key && meta->vm_key->key_name ? meta->vm_key->key_name : "<unknown>",
      meta->vm_key && meta->vm_key->key_name ? meta->vm_key->key_name : "");
}


/* Live count of embedding rows.  Compared against VVEC_META_ACTIVE_NODES it
   catches divergence the epoch pair cannot see on its own -- notably a crash
   that dropped an equal number of inserts and deletes, which leaves the two
   epochs matching but the contents different.  */
static int64
vvec_hidden_row_count (query_instance_t * qi, vvec_meta_t * meta)
{
  caddr_t err = NULL;
  local_cursor_t * lc = NULL;
  query_t * qr;
  char text[1200];
  int64 n = -1;
  snprintf (text, sizeof (text), "select count (*) from %s", meta->vm_hidden_table);
  qr = vvec_compile_text (qi->qi_client, &err, text);
  if (err)
    {
      dk_free_tree (err);
      return -1;
    }
  err = qr_quick_exec (qr, qi->qi_client, "", &lc, 0);
  if (SQL_SUCCESS != err)
    {
      if (lc)
	lc_free (lc);
      qr_free (qr);
      dk_free_tree (err);
      return -1;
    }
  if (lc && lc_next (lc))
    n = unbox (lc_nth_col (lc, 0));
  if (lc)
    lc_free (lc);
  qr_free (qr);
  return n;
}


/* Distance from QUERY to the compact node record CN on a packed page the caller
   already holds.  VVEC_DISTANCE_INF for a missing or deleted record.  Only an
   overflowed vector reads another page. */
static float
vvec_cn_distance (it_cursor_t * itc, vvec_meta_t * meta, db_buf_t cn, const float *query, float query_mag)
{
  float dist;
  if (!cn || vvec_cn_is_deleted (cn))
    return VVEC_DISTANCE_INF;
  if (vvec_cn_has_overflow (cn))
    {
      float * tmp = (float *) dk_alloc (meta->vm_dimension * sizeof (float));
      vvec_read_overflow_from_head (itc, meta, vvec_cn_overflow_head (cn),
	  vvec_cn_overflow_bytes (cn) /* unused — we pass dim */, meta->vm_dimension, tmp);
      dist = vvec_distance_inline (query, query_mag, tmp, vvec_cn_magnitude (cn),
				   meta->vm_dimension, meta->vm_metric);
      dk_free ((caddr_t) tmp, meta->vm_dimension * sizeof (float));
    }
  else
    {
      db_buf_t vptr = vvec_cn_vector_ptr (cn);
      float mag = vvec_cn_magnitude (cn);
      int dim = meta->vm_dimension;
      int metric = meta->vm_metric;
      if (VVEC_METRIC_L2 == metric)
	dist = (float) sqrt ((double) vvec_l2sqr_extf32 (vptr, query, dim));
      else if (VVEC_METRIC_L1 == metric)
	dist = vvec_l1_extf32 (vptr, query, dim);
      else
	{
	  double dot = (double) vvec_ip_extf32 (vptr, query, dim);
	  if (!mag || !query_mag)
	    dist = 2.0f;
	  else
	    dist = (float) (1.0 - (dot / (((double) mag) * ((double) query_mag))));
	}
    }
  return dist;
}


static float
vvec_page_distance (it_cursor_t * itc, vvec_meta_t * meta, vvec_node_ref_t nref, const float *query, float query_mag, int layer, vvec_search_metrics_t * metrics)
{
  buffer_desc_t * buf = NULL;
  float dist;
  dp_addr_t page_dp;
  int slot;
  if (0 == nref)
    return VVEC_DISTANCE_INF;
  page_dp = VVEC_NREF_PAGE (nref);
  slot = VVEC_NREF_SLOT (nref);
  if (meta->vm_arena)
    {
      float ad;
      if (vvec_arena_distance (meta->vm_arena, nref, query, query_mag, meta->vm_metric, meta->vm_dimension, &ad))
	{
	  if (0 == layer && metrics)
	    { metrics->vsm_layer0_visits++; metrics->vsm_layer0_hits++; }
	  return ad;
	}
    }
  if (0 == layer)
    {
      if (metrics)
	{
	  metrics->vsm_layer0_visits++;
	  if (IT_DP_TO_BUF (meta->vm_it, page_dp))
	    metrics->vsm_layer0_hits++;
	}
    }
  vvec_page_access (itc, page_dp, PA_READ, &buf);
  {
    int role = vvec_page_role (buf);
    if (role == VVEC_ROLE_PACKED)
      dist = vvec_cn_distance (itc, meta, vvec_pk_node_ptr (buf, slot), query, query_mag);
    else
      {
	if (vvec_node_is_deleted (buf))
	  dist = VVEC_DISTANCE_INF;
	else
	  {
	    dist = vvec_distance_node (itc, buf, query, query_mag, meta->vm_dimension, meta->vm_metric, meta->vm_hnsw_m);
	    if (meta->vm_arena)
	      {
		float * tmp = (float *) dk_alloc (meta->vm_dimension * sizeof (float));
		vvec_node_copy_vector (itc, buf, meta->vm_hnsw_m, meta->vm_dimension, tmp);
		vvec_arena_add (meta->vm_arena, nref, tmp, vvec_float_ref (buf->bd_buffer + VVEC_NODE_MAGNITUDE));
		dk_free ((caddr_t) tmp, meta->vm_dimension * sizeof (float));
	      }
	  }
      }
  }
  vvec_page_release (itc, buf);
  return dist;
}


static vvec_node_ref_t
vvec_greedy_layer (it_cursor_t * itc, vvec_meta_t * meta, vvec_node_ref_t start_nref, const float *query, float query_mag, int layer, vvec_search_metrics_t * metrics, float * best_ret)
{
  float best = vvec_page_distance (itc, meta, start_nref, query, query_mag, layer, metrics);
  vvec_node_ref_t best_nref = start_nref;
  int improved = 1;
  while (improved)
    {
      buffer_desc_t * buf = NULL;
      int inx, n_count;
      vvec_node_ref_t * nb_ptr;
      improved = 0;
      vvec_page_access (itc, VVEC_NREF_PAGE (best_nref), PA_READ, &buf);
      if (vvec_page_role (buf) == VVEC_ROLE_PACKED)
	{
	  db_buf_t cn = vvec_pk_node_ptr (buf, VVEC_NREF_SLOT (best_nref));
	  nb_ptr = vvec_cn_neighbors_ptr (cn) + vvec_cn_layer_base (cn, layer);
	  n_count = cn[VVEC_CN_COUNTS_BASE + layer];
	}
      else
	{
	  int * counts = vvec_node_counts_ptr (buf);
	  nb_ptr = (vvec_node_ref_t *) vvec_node_layer_ptr (buf, meta->vm_hnsw_m, layer);
	  n_count = counts[layer];
	}
      for (inx = 0; inx < n_count; inx++)
	{
	  vvec_node_ref_t cand_nref = nb_ptr[inx];
	  float cand = vvec_page_distance (itc, meta, cand_nref, query, query_mag, layer, metrics);
	  if (cand < best)
	    {
	      best = cand;
	      best_nref = cand_nref;
	      improved = 1;
	    }
	}
      vvec_page_release (itc, buf);
    }
  if (best_ret)
    *best_ret = best;
  return best_nref;
}


static void
vvec_search_layer (it_cursor_t * itc, vvec_meta_t * meta, vvec_node_ref_t entry_nref, const float *query, float query_mag, int layer, int ef, vvec_cand_list_t * result, vvec_search_metrics_t * metrics)
{
  dk_hash_t * visited = hash_table_allocate (257);
  vvec_cand_list_t candidates;
  vvec_candidate_t current;
  float entry_dist;
  vvec_cand_list_init (&candidates, ef + 8);
  vvec_cand_list_init (result, ef + 8);
  sethash (DP_ADDR2VOID ((dp_addr_t) entry_nref), visited, (void *) 1);
  entry_dist = vvec_page_distance (itc, meta, entry_nref, query, query_mag, layer, metrics);
  vvec_cand_list_insert (&candidates, entry_nref, entry_dist);
  if (entry_dist < VVEC_DISTANCE_INF)
    vvec_cand_list_insert (result, entry_nref, entry_dist);
  while (candidates.vcl_fill)
    {
      buffer_desc_t * buf = NULL;
      int inx, n_count;
      vvec_node_ref_t * nb_ptr;
      float worst = result->vcl_fill ? result->vcl_items[result->vcl_fill - 1].vc_distance : (float) 1e30;
      current = vvec_cand_list_pop_first (&candidates);
      if (result->vcl_fill >= ef && current.vc_distance > worst)
	break;
      vvec_page_access (itc, VVEC_NREF_PAGE (current.vc_dp), PA_READ, &buf);
      if (vvec_page_role (buf) == VVEC_ROLE_PACKED)
	{
	  db_buf_t cn = vvec_pk_node_ptr (buf, VVEC_NREF_SLOT (current.vc_dp));
	  nb_ptr = vvec_cn_neighbors_ptr (cn) + vvec_cn_layer_base (cn, layer);
	  n_count = cn[VVEC_CN_COUNTS_BASE + layer];
	}
      else
	{
	  int * counts = vvec_node_counts_ptr (buf);
	  nb_ptr = (vvec_node_ref_t *) vvec_node_layer_ptr (buf, meta->vm_hnsw_m, layer);
	  n_count = counts[layer];
	}
      for (inx = 0; inx < n_count; inx++)
	{
	  vvec_node_ref_t cand_nref = nb_ptr[inx];
	  float cand_dist;
	  if (gethash (DP_ADDR2VOID ((dp_addr_t) cand_nref), visited))
	    continue;
	  sethash (DP_ADDR2VOID ((dp_addr_t) cand_nref), visited, (void *) 1);
	  cand_dist = vvec_page_distance (itc, meta, cand_nref, query, query_mag, layer, metrics);
	  if ((result->vcl_fill < ef || cand_dist < result->vcl_items[result->vcl_fill - 1].vc_distance) && cand_dist < VVEC_DISTANCE_INF)
	    {
	      if (!vvec_cand_list_contains (result, cand_nref))
		vvec_cand_list_insert (result, cand_nref, cand_dist);
	      vvec_cand_list_insert (&candidates, cand_nref, cand_dist);
	      vvec_cand_list_trim (result, ef);
	    }
	}
      vvec_page_release (itc, buf);
    }
  hash_table_free (visited);
  vvec_cand_list_free (&candidates);
}


/* The half of vvec_add_backlink () for a neighbour on a packed page -- the
   format the fast bulk builder writes, so every graph that has been rebuilt at
   10,000 rows or more.  BUF is that page, held for write; SLOT names the
   neighbour's compact record on it.

   A compact record carries exactly as many neighbour slots per layer as it
   uses (vvec_bulk_serialize_packed), so there is never a free slot to append
   into: the new node can only take the place of the neighbour farthest from
   this one, and only when it is nearer.  That is the rule a full legacy list
   already follows -- a packed list is simply always full.

   Distances to neighbours on this same page are taken from BUF directly.  A
   packed page holds many nodes and they are often each other's neighbours;
   asking vvec_page_distance () for one would try to latch BUF a second time. */
static int
vvec_add_backlink_packed (it_cursor_t * itc, vvec_meta_t * meta, buffer_desc_t * buf, int slot,
    vvec_node_ref_t new_nref, float new_dist, int layer, int force)
{
  db_buf_t cn = vvec_pk_node_ptr (buf, slot);
  vvec_node_ref_t * slots;
  vvec_search_metrics_t metrics;
  float * node_vec;
  float node_mag;
  float farthest_dist = -1.0f;
  int farthest_inx = -1;
  int count, inx, linked;
  if (!cn || vvec_cn_is_deleted (cn) || layer > vvec_cn_max_layer (cn))
    return 0;
  count = cn[VVEC_CN_COUNTS_BASE + layer];
  slots = vvec_cn_neighbors_ptr (cn) + vvec_cn_layer_base (cn, layer);
  for (inx = 0; inx < count; inx++)
    if (slots[inx] == new_nref)
      return 1;
  if (!count)
    return 0;
  node_vec = (float *) dk_alloc (meta->vm_dimension * sizeof (float));
  if (vvec_cn_has_overflow (cn))
    vvec_read_overflow_from_head (itc, meta, vvec_cn_overflow_head (cn),
	vvec_cn_overflow_bytes (cn), meta->vm_dimension, node_vec);
  else
    {
      db_buf_t v = vvec_cn_vector_ptr (cn);
      for (inx = 0; inx < meta->vm_dimension; inx++)
	node_vec[inx] = vvec_float_ref (v + (inx * sizeof (float)));
    }
  node_mag = vvec_cn_magnitude (cn);
  memset (&metrics, 0, sizeof (metrics));
  for (inx = 0; inx < count; inx++)
    {
      float d;
      if (VVEC_NREF_PAGE (slots[inx]) == buf->bd_page)
	d = vvec_cn_distance (itc, meta, vvec_pk_node_ptr (buf, VVEC_NREF_SLOT (slots[inx])), node_vec, node_mag);
      else
	d = vvec_page_distance (itc, meta, slots[inx], node_vec, node_mag, layer, &metrics);
      if (d > farthest_dist)
	{
	  farthest_dist = d;
	  farthest_inx = inx;
	}
    }
  linked = farthest_inx >= 0 && (force || new_dist < farthest_dist);
  if (linked)
    slots[farthest_inx] = new_nref;
  dk_free ((caddr_t) node_vec, meta->vm_dimension * sizeof (float));
  return linked;
}


static int
vvec_add_backlink (it_cursor_t * itc, vvec_meta_t * meta, vvec_node_ref_t neighbor_nref, vvec_node_ref_t new_nref, float new_dist, int layer, int force)
{
  buffer_desc_t * buf = NULL;
  float * neighbor_vec = NULL;
  float neighbor_mag;
  vvec_search_metrics_t metrics;
  int * counts;
  vvec_node_ref_t * slots;
  int cap;
  int inx;
  vvec_page_access (itc, VVEC_NREF_PAGE (neighbor_nref), PA_WRITE, &buf);
  buf = vvec_page_delta (itc, buf);
  /* Everything below reads the page as one legacy node.  A packed page is
     several compact records, and treating it as a legacy node wrote the new
     reference into another node's record and followed garbage references
     until the server died. */
  if (VVEC_ROLE_PACKED == vvec_page_role (buf))
    {
      int rc = vvec_add_backlink_packed (itc, meta, buf, VVEC_NREF_SLOT (neighbor_nref), new_nref, new_dist, layer, force);
      vvec_page_release (itc, buf);
      return rc;
    }
  if (vvec_node_is_deleted (buf))
    {
      vvec_page_release (itc, buf);
      return 0;
    }
  counts = vvec_node_counts_ptr (buf);
  slots = (vvec_node_ref_t *) vvec_node_layer_ptr (buf, meta->vm_hnsw_m, layer);
  cap = vvec_node_layer_capacity (meta->vm_hnsw_m, layer);
  for (inx = 0; inx < counts[layer]; inx++)
    if (slots[inx] == new_nref)
      {
	vvec_page_release (itc, buf);
	return 1;
      }
  if (counts[layer] < cap)
    {
      slots[counts[layer]++] = new_nref;
      vvec_page_release (itc, buf);
      return 1;
    }
  else
    {
      int farthest_inx = -1, linked;
      float farthest_dist = -1.0f;
      neighbor_vec = (float *) dk_alloc (meta->vm_dimension * sizeof (float));
      vvec_node_copy_vector (itc, buf, meta->vm_hnsw_m, meta->vm_dimension, neighbor_vec);
      neighbor_mag = vvec_float_ref (buf->bd_buffer + VVEC_NODE_MAGNITUDE);
      memset (&metrics, 0, sizeof (metrics));
      for (inx = 0; inx < cap; inx++)
	{
	  float dist;
	  dist = vvec_page_distance (itc, meta, slots[inx], neighbor_vec, neighbor_mag, layer, &metrics);
	  if (dist > farthest_dist)
	    {
	      farthest_dist = dist;
	      farthest_inx = inx;
	    }
	}
      linked = farthest_inx >= 0 && (force || new_dist < farthest_dist);
      if (linked)
	slots[farthest_inx] = new_nref;
      dk_free ((caddr_t) neighbor_vec, meta->vm_dimension * sizeof (float));
      vvec_page_release (itc, buf);
      return linked;
    }
}


static vvec_node_ref_t
vvec_insert_graph (query_instance_t * qi, vvec_meta_t * meta, caddr_t row_id, const float *vec, float magnitude)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * root = NULL;
  buffer_desc_t * node = NULL;
  buffer_desc_t * entry_buf = NULL;
  vvec_node_ref_t entry_nref;
  vvec_node_ref_t new_nref;
  vvec_node_ref_t nodes_head;
  int root_max_layer;
  int new_layer;
  int layer;
  int inx;
  int entry_deleted = 0;
  int64 row_id_i64;
  vvec_search_metrics_t metrics;
  int write_pages = 0;
  int overflow_pages = 0;
  time_msec_t start_time = get_msec_real_time ();
  if (!vvec_row_id_to_i64 (row_id, &row_id_i64))
    sqlr_new_error ("22023", "VEC35", "Vector index row id for %s must be an integer value.", meta->vm_key ? meta->vm_key->key_name : "<unknown>");
  memset (&metrics, 0, sizeof (metrics));
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);
  meta->vm_arena = vvec_arena_for_key (meta->vm_key ? meta->vm_key->key_id : 0, meta->vm_dimension);
  vvec_root_read (itc, meta->vm_it, PA_WRITE, &root);
  root = vvec_page_delta (itc, root);
  entry_nref = (vvec_node_ref_t) vvec_meta_ref_i32 (root, VVEC_META_ENTRY_DP);
  nodes_head = (vvec_node_ref_t) vvec_meta_ref_i32 (root, VVEC_META_NODE_HEAD);
  root_max_layer = vvec_meta_ref_i32 (root, VVEC_META_MAX_LAYER);
  if (entry_nref)
    {
      vvec_page_access (itc, VVEC_NREF_PAGE (entry_nref), PA_READ, &entry_buf);
      /* The entry point is a packed record whenever the fast builder chose it. */
      if (VVEC_ROLE_PACKED == vvec_page_role (entry_buf))
	{
	  db_buf_t cn = vvec_pk_node_ptr (entry_buf, VVEC_NREF_SLOT (entry_nref));
	  entry_deleted = !cn || vvec_cn_is_deleted (cn);
	}
      else
	entry_deleted = vvec_node_is_deleted (entry_buf);
      vvec_page_release (itc, entry_buf);
    }
  new_layer = vvec_layer_for_d_id (row_id_i64);
  node = it_new_vec_page (meta->vm_it, entry_nref ? VVEC_NREF_PAGE (entry_nref) : meta->vm_it->it_root, itc);
  new_nref = VVEC_NREF_MAKE (node->bd_page, 0);	/* legacy: slot 0 */
  vvec_meta_set_i32 (node, VVEC_NODE_MAGIC, VVEC_MAGIC);
  vvec_meta_set_i32 (node, VVEC_NODE_ROLE, VVEC_ROLE_NODE);
  vvec_meta_set_i32 (node, VVEC_NODE_VERSION, VVEC_VERSION);
  vvec_meta_set_i32 (node, VVEC_NODE_FLAGS, 0);
  vvec_meta_set_i32 (node, VVEC_NODE_NEXT_DP, (int32) nodes_head);
  vvec_meta_set_i32 (node, VVEC_NODE_MAX_LAYER, new_layer);
  vvec_meta_set_i32 (node, VVEC_NODE_DIM, meta->vm_dimension);
  vvec_meta_set_i32 (node, VVEC_NODE_METRIC, meta->vm_metric);
  vvec_meta_set_i32 (node, VVEC_NODE_HNSW_M, meta->vm_hnsw_m);
  vvec_meta_set_i64 (node, VVEC_NODE_D_ID, row_id_i64);
  vvec_float_set (node->bd_buffer + VVEC_NODE_MAGNITUDE, magnitude);
  memset (node->bd_buffer + VVEC_NODE_COUNTS, 0, PAGE_SZ - VVEC_NODE_COUNTS);
  if (!VVEC_DIM_FITS_INLINE (meta->vm_hnsw_m, meta->vm_dimension))
    {
      dp_addr_t overflow_head = 0;
      overflow_pages = vvec_write_overflow_vector (itc, meta, node->bd_page, vec, &overflow_head);
      vvec_node_set_overflow (node, meta->vm_hnsw_m, overflow_head, meta->vm_dimension * sizeof (float));
      write_pages += overflow_pages;
    }
  else
    {
      for (inx = 0; inx < meta->vm_dimension; inx++)
	vvec_float_set (vvec_node_vector_ptr (node, meta->vm_hnsw_m) + (inx * sizeof (float)), vec[inx]);
    }
  write_pages++;
  if (meta->vm_arena)
    vvec_arena_add (meta->vm_arena, new_nref, vec, magnitude);
  if (!entry_nref)
    {
      vvec_meta_set_i32 (root, VVEC_META_ENTRY_DP, (int32) new_nref);
      vvec_meta_set_i32 (root, VVEC_META_NODE_HEAD, (int32) new_nref);
      vvec_meta_set_i32 (root, VVEC_META_MAX_LAYER, new_layer);
    }
  else
    {
      vvec_node_ref_t entry = entry_nref;
      float ignore;
      for (layer = root_max_layer; layer > new_layer; layer--)
	entry = vvec_greedy_layer (itc, meta, entry, vec, magnitude, layer, &metrics, &ignore);
      for (layer = (new_layer < root_max_layer ? new_layer : root_max_layer); layer >= 0; layer--)
	{
	  vvec_cand_list_t res;
	  int keep, backlinks = 0;
	  int * counts = vvec_node_counts_ptr (node);
	  vvec_node_ref_t * slots = (vvec_node_ref_t *) vvec_node_layer_ptr (node, meta->vm_hnsw_m, layer);
	  vvec_search_layer (itc, meta, entry, vec, magnitude, layer, meta->vm_ef_construction, &res, &metrics);
	  keep = res.vcl_fill < vvec_node_layer_capacity (meta->vm_hnsw_m, layer) ? res.vcl_fill : vvec_node_layer_capacity (meta->vm_hnsw_m, layer);
	  counts[layer] = keep;
	  for (inx = 0; inx < keep; inx++)
	    {
	      slots[inx] = res.vcl_items[inx].vc_dp;
	      backlinks += vvec_add_backlink (itc, meta, res.vcl_items[inx].vc_dp, new_nref, res.vcl_items[inx].vc_distance, layer, 0);
	    }
	  /* Full lists refuse a node that is not strictly nearer, so on ties every
	     backlink can be refused and the new node has no way in at level 0. */
	  if (0 == layer && keep && !backlinks)
	    vvec_add_backlink (itc, meta, res.vcl_items[0].vc_dp, new_nref, res.vcl_items[0].vc_distance, layer, 1);
	  if (res.vcl_fill)
	    entry = res.vcl_items[0].vc_dp;
	  vvec_cand_list_free (&res);
	}
      if (entry_deleted || new_layer > root_max_layer)
	{
	  vvec_meta_set_i32 (root, VVEC_META_ENTRY_DP, (int32) new_nref);
	  if (new_layer > root_max_layer)
	    vvec_meta_set_i32 (root, VVEC_META_MAX_LAYER, new_layer);
	}
      vvec_meta_set_i32 (root, VVEC_META_NODE_HEAD, (int32) new_nref);
    }
  vvec_meta_inc_i64 (root, VVEC_META_TOTAL_NODES, 1);
  vvec_meta_inc_i64 (root, VVEC_META_ACTIVE_NODES, 1);
  vvec_meta_inc_i64 (root, VVEC_META_INSERT_COUNT, 1);
  vvec_meta_inc_i64 (root, VVEC_META_EPOCH, 1);
  if (overflow_pages)
    vvec_meta_inc_i64 (root, VVEC_META_OVERFLOW_PAGES, overflow_pages);
  vvec_meta_inc_i64 (root, VVEC_META_BYTES_WRITTEN, ((int64) PAGE_SZ) * (write_pages + 1));
  vvec_meta_inc_i64 (root, VVEC_META_INSERT_USEC, (get_msec_real_time () - start_time) * 1000);
  vvec_page_release (itc, node);
  vvec_page_release (itc, root);
  return new_nref;
}


static int
vvec_search_graph (query_instance_t * qi, vvec_meta_t * meta, const float *query, float query_mag, int k, int ef_search, vvec_cand_list_t * results, vvec_search_metrics_t * metrics)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * root = NULL;
  vvec_node_ref_t entry_nref;
  int max_layer;
  int layer;
  time_msec_t start_time = get_msec_real_time ();
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);
  vvec_root_read (itc, meta->vm_it, PA_READ, &root);
  entry_nref = (vvec_node_ref_t) vvec_meta_ref_i32 (root, VVEC_META_ENTRY_DP);
  max_layer = vvec_meta_ref_i32 (root, VVEC_META_MAX_LAYER);
  vvec_page_release (itc, root);
  if (!entry_nref)
    {
      vvec_cand_list_init (results, 4);
      return 0;
    }
  for (layer = max_layer; layer > 0; layer--)
    entry_nref = vvec_greedy_layer (itc, meta, entry_nref, query, query_mag, layer, metrics, NULL);
  vvec_search_layer (itc, meta, entry_nref, query, query_mag, 0, ef_search > k ? ef_search : k, results, metrics);
  if (results->vcl_fill > k)
    results->vcl_fill = k;
  vvec_root_read (itc, meta->vm_it, PA_WRITE, &root);
  root = vvec_page_delta (itc, root);
  vvec_meta_inc_i64 (root, VVEC_META_SEARCH_COUNT, 1);
  vvec_meta_inc_i64 (root, VVEC_META_SEARCH_USEC, (get_msec_real_time () - start_time) * 1000);
  vvec_meta_inc_i64 (root, VVEC_META_LAYER0_VISITS, metrics->vsm_layer0_visits);
  vvec_meta_inc_i64 (root, VVEC_META_LAYER0_HITS, metrics->vsm_layer0_hits);
  vvec_page_release (itc, root);
  return results->vcl_fill;
}


static caddr_t
vvec_search_result_box (query_instance_t * qi, vvec_meta_t * meta, vvec_cand_list_t * results)
{
  caddr_t * rows;
  caddr_t ret;
  int out_fill = 0;
  int inx;
  rows = (caddr_t *) dk_alloc_box (results->vcl_fill * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < results->vcl_fill; inx++)
    {
      caddr_t row_id = vvec_hidden_row_id_by_node (qi, meta, results->vcl_items[inx].vc_dp);
      if (!row_id || DV_DB_NULL == DV_TYPE_OF (row_id))
	continue;
      /* Never hand back a hit with no backing row.  A phantom neighbour is
         indistinguishable from a real one to the caller.  */
      if (!vvec_hidden_row_exists (qi, meta, row_id, NULL))
	{
	  /* Absence from this transaction's snapshot does not prove rollback: a
	     concurrent insert publishes its graph node before its hidden row commits.
	     Reaping here used to retire those valid in-flight nodes.  Filter the hit;
	     orphan cleanup belongs to reconciliation, not a search snapshot. */
	  dk_free_tree (row_id);
	  continue;
	}
      if (out_fill >= results->vcl_fill)
	break;
      {
      caddr_t * row = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      row[0] = row_id;
      row[1] = box_double ((double) results->vcl_items[inx].vc_distance);
      rows[out_fill++] = (caddr_t) row;
      }
    }
  if (out_fill == results->vcl_fill)
    ret = (caddr_t) rows;
  else
    {
      caddr_t * trimmed = (caddr_t *) dk_alloc_box (out_fill * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      if (out_fill)
	memcpy (trimmed, rows, out_fill * sizeof (caddr_t));
      dk_free_box ((box_t) rows);
      ret = (caddr_t) trimmed;
    }
  vvec_cand_list_free (results);
  return ret;
}


/* Search retains nrefs after releasing the pages that supplied them, and result
 * packing rereads the winning nrefs to obtain their row ids.  Hold the graph
 * read gate across both phases so rebuild cannot recycle any of those pages in
 * between.  Health reconciliation is deliberately outside this helper: it may
 * itself rebuild and must do so before the caller takes the read side. */
static caddr_t
vvec_search_graph_and_pack (query_instance_t * qi, vvec_meta_t * meta,
    const float * query, float query_mag, int k, int ef_search,
    vvec_search_metrics_t * metrics)
{
  vvec_cand_list_t results;
  rwlock_t * gate = vvec_graph_read_lock (meta->vm_it);
  caddr_t ret = NULL;
  QR_RESET_CTX_T (qi->qi_thread)
    {
      vvec_search_graph (qi, meta, query, query_mag, k, ef_search, &results, metrics);
      ret = vvec_search_result_box (qi, meta, &results);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_graph_unlock (gate);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_graph_unlock (gate);
  return ret;
}


/* Validation consumes only the nrefs returned by the graph walk and never
 * dereferences them afterwards, so its read-side lifetime ends with the walk. */
static int
vvec_search_graph_for_validate (query_instance_t * qi, vvec_meta_t * meta,
    const float * query, float query_mag, int k, int ef_search,
    vvec_cand_list_t * results, vvec_search_metrics_t * metrics)
{
  rwlock_t * gate = vvec_graph_read_lock (meta->vm_it);
  int fill = 0;
  QR_RESET_CTX_T (qi->qi_thread)
    {
      fill = vvec_search_graph (qi, meta, query, query_mag, k, ef_search, results, metrics);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_graph_unlock (gate);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_graph_unlock (gate);
  return fill;
}


static caddr_t
vvec_metrics_box (buffer_desc_t * root, vvec_meta_t * meta)
{
  caddr_t * ret = (caddr_t *) dk_alloc_box (24 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int fill = 0;
  ret[fill++] = box_dv_short_string ("dimension");
  ret[fill++] = box_num (meta->vm_dimension);
  ret[fill++] = box_dv_short_string ("distance_metric");
  ret[fill++] = box_dv_short_string ((char *) vvec_metric_name (meta->vm_metric));
  ret[fill++] = box_dv_short_string ("hnsw_m");
  ret[fill++] = box_num (meta->vm_hnsw_m);
  ret[fill++] = box_dv_short_string ("managed_rows");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_ACTIVE_NODES));
  ret[fill++] = box_dv_short_string ("graph_nodes");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_TOTAL_NODES));
  ret[fill++] = box_dv_short_string ("deleted_nodes");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_DELETED_NODES));
  ret[fill++] = box_dv_short_string ("insert_count");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_INSERT_COUNT));
  ret[fill++] = box_dv_short_string ("search_count");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_SEARCH_COUNT));
  ret[fill++] = box_dv_short_string ("search_usec");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_SEARCH_USEC));
  ret[fill++] = box_dv_short_string ("bytes_written");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_BYTES_WRITTEN));
  ret[fill++] = box_dv_short_string ("layer0_hit_rate");
  if (vvec_meta_ref_i64 (root, VVEC_META_LAYER0_VISITS))
    ret[fill++] = box_double (((double) vvec_meta_ref_i64 (root, VVEC_META_LAYER0_HITS)) / ((double) vvec_meta_ref_i64 (root, VVEC_META_LAYER0_VISITS)));
  else
    ret[fill++] = box_double (1.0);
  ret[fill++] = box_dv_short_string ("state");
  ret[fill++] = box_dv_short_string (meta->vm_state ? meta->vm_state : VVEC_STATE_READY_FOR_INTERNAL_LOAD);
  return (caddr_t) ret;
}


static caddr_t
vvec_page_stats_box (buffer_desc_t * root, vvec_meta_t * meta, it_cursor_t * itc)
{
  caddr_t * ret = (caddr_t *) dk_alloc_box (20 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int fill = 0;
  int64 physical_pages = 0;
  int is_packed = 0;
  /* Walk the node chain to count physical node pages and detect packed format. */
  vvec_node_ref_t next = (vvec_node_ref_t) vvec_meta_ref_i32 (root, VVEC_META_NODE_HEAD);
  while (next)
    {
      buffer_desc_t * node = NULL;
      dp_addr_t page_dp = VVEC_NREF_PAGE (next);
      vvec_page_access (itc, page_dp, PA_READ, &node);
      if (vvec_page_role (node) == VVEC_ROLE_PACKED)
	{
	  is_packed = 1;
	  physical_pages++;
	  next = (vvec_node_ref_t) LONG_REF (node->bd_buffer + VVEC_PK_NEXT_DP) << VVEC_NREF_SLOT_BITS;
	}
      else
	{
	  physical_pages++;
	  next = (vvec_node_ref_t) vvec_meta_ref_i32 (node, VVEC_NODE_NEXT_DP);
	}
      vvec_page_release (itc, node);
    }
  ret[fill++] = box_dv_short_string ("metadata_pages");
  ret[fill++] = box_num (1);
  ret[fill++] = box_dv_short_string ("node_pages");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_TOTAL_NODES));
  ret[fill++] = box_dv_short_string ("deleted_pages");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_DELETED_NODES));
  ret[fill++] = box_dv_short_string ("entry_point_dp");
  ret[fill++] = box_num (vvec_meta_ref_i32 (root, VVEC_META_ENTRY_DP));
  ret[fill++] = box_dv_short_string ("max_layer");
  ret[fill++] = box_num (vvec_meta_ref_i32 (root, VVEC_META_MAX_LAYER));
  ret[fill++] = box_dv_short_string ("inline_dim_limit");
  ret[fill++] = box_num (vvec_max_inline_dimension (meta->vm_hnsw_m));
  ret[fill++] = box_dv_short_string ("overflow_pages");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_OVERFLOW_PAGES));
  ret[fill++] = box_dv_short_string ("deleted_overflow_pages");
  ret[fill++] = box_num (vvec_meta_ref_i64 (root, VVEC_META_DELETED_OVERFLOW_PAGES));
  ret[fill++] = box_dv_short_string ("physical_node_pages");
  ret[fill++] = box_num (physical_pages);
  ret[fill++] = box_dv_short_string ("format");
  ret[fill++] = box_dv_short_string (is_packed ? "packed" : "legacy");
  return (caddr_t) ret;
}


int
vvec_index_opts_p (caddr_t * opts)
{
  return NULL != vvec_vector_opts (opts);
}


int
vvec_key_p (dbe_key_t * key)
{
  return key && key->key_options && NULL != vvec_vector_opts (key->key_options);
}


/* +restore-crash-dump rebuilds a fresh database, so global page numbers in a
   dumped DPF_VEC image cannot be reused: their extents may belong to different
   trees in the new allocation layout.  Keep a per-process old->new map while
   the dump log is replayed.  The second hash lets translation be idempotent --
   a later WAL delta is applied to an already-relocated page and then the whole
   page's references are normalized again. */
static dk_hash_64_t * vvec_restore_dp_map = NULL;
static dk_hash_64_t * vvec_restore_page_images = NULL;


static void
vvec_restore_maps_init (void)
{
  if (!vvec_restore_dp_map)
    {
      vvec_restore_dp_map = hash_table_allocate_64 (4096);
      vvec_restore_page_images = hash_table_allocate_64 (4096);
      id_hash_set_rehash_pct (vvec_restore_dp_map, 120);
      id_hash_set_rehash_pct (vvec_restore_page_images, 120);
    }
}


static dp_addr_t
vvec_restore_map_dp (it_cursor_t * itc, index_tree_t * it, key_id_t key_id,
    dp_addr_t old_dp, int create, caddr_t * err_ret)
{
  int64 mapped = 0;
  int64 old_key;
  buffer_desc_t * buf;
  if (!old_dp)
    return 0;
  vvec_restore_maps_init ();
  old_key = VVEC_PAGE_IMAGE_KEY (key_id, old_dp);
  gethash_64 (mapped, old_key, vvec_restore_dp_map);
  if (mapped)
    return (dp_addr_t) mapped;
  if (!create)
    {
      *err_ret = srv_make_new_error ("42000", "VEC92",
	  "LOG_VEC_PAGE: restored vector page %lu has no relocation mapping",
	  (unsigned long) old_dp);
      return 0;
    }
  buf = it_new_page (it, it->it_root, DPF_VEC, 0, itc);
  if (!buf)
    {
      *err_ret = srv_make_new_error ("42000", "VEC85",
	  "LOG_VEC_PAGE: could not allocate relocation for page %lu",
	  (unsigned long) old_dp);
      return 0;
    }
  mapped = (int64) buf->bd_page;
  sethash_64 (old_key, vvec_restore_dp_map, mapped);
  vvec_page_release (itc, buf);
  return (dp_addr_t) mapped;
}


static void
vvec_restore_map_root (key_id_t key_id, dp_addr_t old_dp, dp_addr_t new_dp)
{
  vvec_restore_maps_init ();
  sethash_64 (VVEC_PAGE_IMAGE_KEY (key_id, old_dp), vvec_restore_dp_map,
      (int64) new_dp);
}


static db_buf_t
vvec_restore_old_image (key_id_t key_id, dp_addr_t old_dp, int create,
    caddr_t * err_ret)
{
  int64 image_ptr = 0;
  int64 image_key;
  db_buf_t image;
  vvec_restore_maps_init ();
  image_key = VVEC_PAGE_IMAGE_KEY (key_id, old_dp);
  gethash_64 (image_ptr, image_key, vvec_restore_page_images);
  if (image_ptr)
    return (db_buf_t) (ptrlong) image_ptr;
  if (!create)
    {
      *err_ret = srv_make_new_error ("42000", "VEC91",
	  "LOG_VEC_PAGE: restored vector page %lu has no base image for a delta",
	  (unsigned long) old_dp);
      return NULL;
    }
  /* Zeroed, not merely allocated: the record that creates this shadow describes
     a new page, and a new-page record carries only the head of it -- the tail it
     leaves out is zeroes by definition.  Without this the tail would be whatever
     dk_alloc () handed back. */
  image = (db_buf_t) dk_alloc (PAGE_SZ);
  memset (image, 0, PAGE_SZ);
  sethash_64 (image_key, vvec_restore_page_images, (int64) (ptrlong) image);
  return image;
}


static int
vvec_restore_xlate_dp (it_cursor_t * itc, index_tree_t * it, key_id_t key_id,
    db_buf_t place, caddr_t * err_ret)
{
  dp_addr_t old_dp = (dp_addr_t) LONG_REF (place);
  dp_addr_t new_dp;
  if (!old_dp)
    return 1;
  new_dp = vvec_restore_map_dp (itc, it, key_id, old_dp, 1, err_ret);
  if (!new_dp)
    return 0;
  LONG_SET (place, new_dp);
  return 1;
}


static int
vvec_restore_xlate_nref (it_cursor_t * itc, index_tree_t * it, key_id_t key_id,
    db_buf_t place, caddr_t * err_ret)
{
  vvec_node_ref_t old_ref = (vvec_node_ref_t) LONG_REF (place);
  dp_addr_t new_dp;
  if (!old_ref)
    return 1;
  new_dp = vvec_restore_map_dp (itc, it, key_id, VVEC_NREF_PAGE (old_ref), 1,
      err_ret);
  if (!new_dp)
    return 0;
  LONG_SET (place, VVEC_NREF_MAKE (new_dp, VVEC_NREF_SLOT (old_ref)));
  return 1;
}


/* Rewrite every page reference in one full DPF_VEC image.  Redo has to know the
   page format: a generic byte-for-byte copy would carry stale page numbers. */
static int
vvec_restore_xlate_image (it_cursor_t * itc, index_tree_t * it, key_id_t key_id,
    db_buf_t image, caddr_t * err_ret)
{
  buffer_desc_t fake;
  int role = LONG_REF (image + DP_DATA + 4);
  int inx;
  memset (&fake, 0, sizeof (fake));
  fake.bd_buffer = image;
  if (VVEC_ROLE_META == role)
    return vvec_restore_xlate_nref (itc, it, key_id,
	image + VVEC_META_ENTRY_DP, err_ret)
	&& vvec_restore_xlate_nref (itc, it, key_id,
	image + VVEC_META_NODE_HEAD, err_ret);
  if (VVEC_ROLE_OVERFLOW == role)
    return vvec_restore_xlate_dp (itc, it, key_id,
	image + VVEC_OV_NEXT_DP, err_ret);
  if (VVEC_ROLE_NODE == role)
    {
      int hnsw_m = LONG_REF (image + VVEC_NODE_HNSW_M);
      int * counts = (int *) (image + VVEC_NODE_COUNTS);
      vvec_node_ref_t * refs = (vvec_node_ref_t *)
	  (image + VVEC_NODE_COUNTS + (VVEC_MAX_LAYERS * sizeof (int32)));
      /* The slot array ends exactly at the vector offset, so bounding that one
	 expression bounds every refs[] and the overflow ref that follows it. */
      if (hnsw_m <= 0
	  || vvec_node_vector_offset (hnsw_m) + VVEC_NODE_OVERFLOW_REF_BYTES > PAGE_SZ)
	goto bad_image;
      if (!vvec_restore_xlate_nref (itc, it, key_id,
	      image + VVEC_NODE_NEXT_DP, err_ret))
	return 0;
      for (inx = 0; inx < VVEC_MAX_LAYERS; inx++)
	{
	  int nth, count = counts[inx];
	  int cap = vvec_node_layer_capacity (hnsw_m, inx);
	  int base = vvec_node_layer_base (hnsw_m, inx);
	  if (count < 0 || count > cap)
	    goto bad_image;
	  for (nth = 0; nth < count; nth++)
	    if (!vvec_restore_xlate_nref (itc, it, key_id,
		(db_buf_t) &refs[base + nth], err_ret))
	      return 0;
	}
      if (0 != (LONG_REF (image + VVEC_NODE_FLAGS) & VVEC_NODE_OVERFLOW)
	  && !vvec_restore_xlate_dp (itc, it, key_id,
	      vvec_node_vector_ptr (&fake, hnsw_m) + VVEC_NODE_OVERFLOW_HEAD_OFF,
	      err_ret))
	return 0;
      return 1;
    }
  if (VVEC_ROLE_PACKED == role)
    {
      int count = (int) image[VVEC_PK_NODE_COUNT];
      if (count < 0 || count > VVEC_NREF_MAX_SLOTS)
	goto bad_image;
      if (!vvec_restore_xlate_dp (itc, it, key_id,
	      image + VVEC_PK_NEXT_DP, err_ret))
	return 0;
      for (inx = 0; inx < count; inx++)
	{
	  db_buf_t cn = vvec_pk_node_ptr (&fake, inx);
	  int nth, total, n_layers;
	  vvec_node_ref_t * refs;
	  /* A packed record's extent is described by bytes inside the record
	     itself, so each one has to be bounded before it is used to reach the
	     next: the directory offset, then the layer count that sizes the
	     per-layer counts, then the neighbour total those counts add up to. */
	  if (!cn || cn < image + VVEC_PK_DATA_BASE || cn >= image + PAGE_SZ)
	    goto bad_image;
	  n_layers = vvec_cn_n_layers (cn);
	  if (n_layers > VVEC_MAX_LAYERS
	      || cn + VVEC_CN_COUNTS_BASE + n_layers > image + PAGE_SZ)
	    goto bad_image;
	  total = vvec_cn_total_neighbors (cn);
	  refs = vvec_cn_neighbors_ptr (cn);
	  if ((db_buf_t) (refs + total) > image + PAGE_SZ)
	    goto bad_image;
	  for (nth = 0; nth < total; nth++)
	    if (!vvec_restore_xlate_nref (itc, it, key_id,
		(db_buf_t) &refs[nth], err_ret))
	      return 0;
	  if (vvec_cn_has_overflow (cn))
	    {
	      db_buf_t ov = vvec_cn_vector_ptr (cn) + VVEC_NODE_OVERFLOW_HEAD_OFF;
	      if (ov + sizeof (int32) > image + PAGE_SZ)
		goto bad_image;
	      if (!vvec_restore_xlate_dp (itc, it, key_id, ov, err_ret))
		return 0;
	    }
	}
      return 1;
    }
bad_image:
  *err_ret = srv_make_new_error ("42000", "VEC90",
      "LOG_VEC_PAGE: malformed vector page image during relocation");
  return 0;
}


/* The dumped root must land on the root the rebuilt database already made for
   this key rather than on a relocation of its own.  No other page refers to the
   root -- neighbour slots, the node chain, ENTRY_DP and NODE_HEAD all name node
   pages -- so nothing can reserve a page for it before its own record shows up,
   and seeding it here is enough whenever that happens to be. */
static void
vvec_restore_seed_root (index_tree_t * it, key_id_t key_id, dp_addr_t dp, db_buf_t image)
{
  if (VVEC_ROLE_META != LONG_REF (image + DP_DATA + 4))
    return;
  vvec_restore_map_root (key_id, dp, it->it_root);
}


/* Make NEW_DP ready to take a full image.  It is normally a page this restore
   already reserved, but the root can come back from a restored registry as a
   page number the rebuilt database never allocated, so the free case reserves it
   the same way the same-database new-page path does. */
static int
vvec_restore_page_for_write (it_cursor_t * itc, index_tree_t * it, dbe_key_t * key,
    key_id_t key_id, dp_addr_t new_dp, buffer_desc_t ** buf_ret, caddr_t * err_ret)
{
  buffer_desc_t * buf = NULL;
  if (!IT_PAGE_IN_RANGE (it, new_dp))
    {
      *err_ret = srv_make_new_error ("42000", "VEC84",
	  "LOG_VEC_PAGE: relocated page %lu is outside the storage extent",
	  (unsigned long) new_dp);
      return 0;
    }
  if (dbs_is_free_page (it->it_storage, new_dp))
    {
      if (DBS_DP_TO_EM (it->it_storage, new_dp) != it->it_extent_map)
	{
	  *err_ret = srv_make_new_error ("42000", "VEC89",
	      "LOG_VEC_PAGE: page %lu is not owned by vector index %s's extent map",
	      (unsigned long) new_dp, key->key_name ? key->key_name : "(unnamed)");
	  return 0;
	}
      buf = it_new_page_exact (it, new_dp, DPF_VEC);
      if (!buf)
	{
	  *err_ret = srv_make_new_error ("42000", "VEC85",
	      "LOG_VEC_PAGE: could not allocate relocated page %lu",
	      (unsigned long) new_dp);
	  return 0;
	}
      *buf_ret = buf;
      return 1;
    }
  vvec_page_access (itc, new_dp, PA_WRITE, &buf);
  if (!buf)
    {
      *err_ret = srv_make_new_error ("42000", "VEC85",
	  "LOG_VEC_PAGE: relocated page %lu could not be read for replay",
	  (unsigned long) new_dp);
      return 0;
    }
  if (DPF_VEC != SHORT_REF (buf->bd_buffer + DP_FLAGS)
      || (key_id_t) LONG_REF (buf->bd_buffer + DP_KEY_ID) != key_id)
    {
      vvec_page_release (itc, buf);
      *err_ret = srv_make_new_error ("42000", "VEC86",
	  "LOG_VEC_PAGE: relocated page %lu is not owned by vector key %lu, refusing to overwrite it",
	  (unsigned long) new_dp, (unsigned long) key_id);
      return 0;
    }
  *buf_ret = vvec_page_delta (itc, buf);
  return 1;
}


/* Redo one record into a database rebuilt from scratch, where the record's page
   number describes the original database's allocation and means nothing here.
   The record is folded into a shadow of the original page, kept in the original
   page numbering because that is the only numbering a later delta is expressed
   in; the shadow is then copied, every reference in the copy is rewritten to the
   pages this restore allocated, and the copy is written whole -- translation can
   change bytes outside the record's own range, so a partial write would not
   do. */
static int
vvec_restore_replay_page (index_tree_t * it, dbe_key_t * key, key_id_t key_id,
    dp_addr_t dp, int offset, db_buf_t bytes, int len, int is_new_page, caddr_t * err_ret)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * buf = NULL;
  db_buf_t shadow;
  db_buf_t image;
  dp_addr_t new_dp;

  /* Whether this record initializes a page is the caller's finding, not
     something to re-derive from the geometry: a new-page record carries only the
     head of its page, so "len == PAGE_SZ" would call a compact one a delta and
     refuse it for having no base image. */
  shadow = vvec_restore_old_image (key_id, dp, is_new_page, err_ret);
  if (!shadow)
    return 0;
  memcpy (shadow + offset, bytes, len);
  if (DPF_VEC != SHORT_REF (shadow + DP_FLAGS)
      || (key_id_t) LONG_REF (shadow + DP_KEY_ID) != key_id)
    {
      *err_ret = srv_make_new_error ("42000", "VEC90",
	  "LOG_VEC_PAGE: restored image of page %lu is not a DPF_VEC page of key %lu",
	  (unsigned long) dp, (unsigned long) key_id);
      return 0;
    }
  /* Seeding maps the dumped root onto this one, and a zero would be
     indistinguishable from an unmapped page once it is in the hash. */
  if (!it->it_root)
    {
      *err_ret = srv_make_new_error ("42000", "VEC83",
	  "LOG_VEC_PAGE: vector index %s has no root to relocate onto",
	  key->key_name ? key->key_name : "(unnamed)");
      return 0;
    }
  ITC_INIT (itc, it->itc_commit_space, NULL);
  itc_from_it (itc, it);
  vvec_restore_seed_root (it, key_id, dp, shadow);
  new_dp = vvec_restore_map_dp (itc, it, key_id, dp, 1, err_ret);
  if (!new_dp)
    return 0;
  image = (db_buf_t) dk_alloc (PAGE_SZ);
  memcpy (image, shadow, PAGE_SZ);
  if (!vvec_restore_xlate_image (itc, it, key_id, image, err_ret)
      || !vvec_restore_page_for_write (itc, it, key, key_id, new_dp, &buf, err_ret))
    {
      dk_free ((caddr_t) image, PAGE_SZ);
      return 0;
    }
  memcpy (buf->bd_buffer, image, PAGE_SZ);
  vvec_page_release (itc, buf);
  dk_free ((caddr_t) image, PAGE_SZ);
  return 1;
}


/* Called when the replay that built these is over; a restored database does not
   refer to the original page numbers again. */
void
vvec_restore_maps_free (void)
{
  id_hash_iterator_t hit;
  caddr_t key_buf, val_buf;
  if (!vvec_restore_dp_map)
    return;
  id_hash_iterator (&hit, vvec_restore_page_images);
  while (hit_next (&hit, &key_buf, &val_buf))
    {
      db_buf_t image = (db_buf_t) (ptrlong) *(int64 *) val_buf;
      if (image)
	dk_free ((caddr_t) image, PAGE_SZ);
    }
  hash_table_free_64 (vvec_restore_page_images);
  hash_table_free_64 (vvec_restore_dp_map);
  vvec_restore_page_images = NULL;
  vvec_restore_dp_map = NULL;
}


/* Does page DP still belong to the vector index whose key id is KEY_ID?

   Asked, and answered, without touching IT's buffer manager state.  That is
   the whole point: vvec_page_access () installs the page in the tree's
   itm_dp_to_buf and itm_remap, and doing that to a page the tree does not own
   makes the next checkpoint free it once for this tree and once for its real
   owner -- "double free of dp bit in ext", measured with a vector index's page
   number reappearing as a page of an ordinary table.  So the question has to
   be settled before the page is taken, not after.

   Resident in this tree's own map means it is this tree's page and its
   in-memory image is the current one.  Otherwise read it into a buffer of our
   own.  assertion_on_read_fail is cleared around that read: DPF_INDEX is 0, so
   a page of zeroes is a B-tree page as far as buf_disk_read () is concerned
   and it calls pg_make_map (), which finds key id 0 and would GPF the process
   at insert.c:163 rather than let this function form an opinion.  col.c:4730
   clears it for the same reason. */
static int
vvec_replay_page_is_ours (index_tree_t * it, dp_addr_t dp, key_id_t key_id)
{
  it_map_t * itm = IT_DP_MAP (it, dp);
  buffer_desc_t * probe;
  int saved_assertion, ours;

  mutex_enter (&itm->itm_mtx);
  ours = NULL != gethash (DP_ADDR2VOID (dp), &itm->itm_dp_to_buf);
  mutex_leave (&itm->itm_mtx);
  if (ours)
    return 1;

  probe = buffer_allocate (DPF_VEC);
  probe->bd_page = dp;
  probe->bd_physical_page = dp;
  probe->bd_storage = it->it_storage;
  probe->bd_tree = it;
  saved_assertion = assertion_on_read_fail;
  assertion_on_read_fail = 0;
  buf_disk_read (probe);
  assertion_on_read_fail = saved_assertion;
  ours = (DPF_VEC == SHORT_REF (probe->bd_buffer + DP_FLAGS)
      && (key_id_t) LONG_REF (probe->bd_buffer + DP_KEY_ID) == key_id);
  if (probe->bd_content_map)
    {
      /* buffer_free () does not give a content map back, and pg_make_map ()
	 leaves an empty one behind on the page-of-zeroes path. */
      pm_store (probe, probe->bd_content_map->pm_size, (void *) probe->bd_content_map);
      probe->bd_content_map = NULL;
    }
  buffer_free (probe);
  return ours;
}


/* Redo one LOG_VEC_PAGE record: write LEN bytes at OFFSET into the DPF_VEC
   page DP of the vector index whose key id is KEY_ID.

   This is the one place where a value read out of the transaction log is
   copied into a database page at an offset the log itself chose, so it is a
   memory-safety boundary and not merely a consistency one.  Recovery runs
   before any user is authenticated and reads whatever .trx file is sitting
   next to the database, so every field is treated as hostile: the geometry is
   bounds-checked against PAGE_SZ with the sum checked too (not just the parts),
   the page number is checked against the storage extent and the free map, and
   the page is confirmed to actually be a DPF_VEC page before a byte is
   written.  Without that last check a forged record could name a B-tree, blob
   or the checkpoint tree and have redo scribble over it.

   Cannot fail, and takes no error out-parameter so that it cannot be made to.
   A record that cannot be applied is logged, warned about, charged to the index
   through vvec_replay_condemn (), and skipped.  Returning an error instead would
   reach log_replay_entry (), which rolls the whole transaction back (log.c) --
   and that transaction also carries the ordinary row inserts committed with it,
   including the embeddings the rebuild reads.  Refusing a record would then
   destroy the committed rows needed to reconstruct what the refusal was
   protecting, and the index would come back self-consistent and quietly short of
   data.  The graph is derived; the rows are not. */
int
vvec_replay_page (key_id_t key_id, dp_addr_t dp, int offset, db_buf_t bytes, int len)
{
  dbe_key_t *key;
  dbe_key_frag_t *kf;
  index_tree_t *it;
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  buffer_desc_t *buf = NULL;

  /* A new-page record carries the head of a page whose tail is zeroes; it says
     so with VVEC_LOG_NEW_PAGE in place of an offset.  Normalize it to an offset
     of 0 and remember which kind of record this is -- the free-page branch below
     needs a whole page, and only a new-page record is one.  A log predating the
     tag says the same thing with offset 0 and len PAGE_SZ, which still qualifies. */
  int is_new_page = (VVEC_LOG_NEW_PAGE == offset);
  /* Already condemned: the graph is rebuilt from the embeddings anyway, so the rest of its redo is noise. */
  if (vvec_replay_condemned_p (key_id))
    return 1;
  if (is_new_page)
    offset = 0;
  else if (0 == offset && PAGE_SZ == len)
    is_new_page = 1;

  /* Geometry first, before anything dereferences a page.  offset and len are
     both already bounded below, so offset + len cannot overflow an int here. */
  if (!bytes || offset < 0 || offset >= PAGE_SZ || len <= 0 || len > PAGE_SZ || offset + len > PAGE_SZ)
    {
      log_error ("LOG_VEC_PAGE: bad page geometry offset=%d len=%d for page %lu of key %lu. "
	  "Skipping the record.", offset, len, (unsigned long) dp, (unsigned long) key_id);
      vvec_replay_condemn (key_id);
      return 1;
    }
  key = sch_id_to_key (wi_inst.wi_schema, key_id);
  if (!key || !vvec_key_p (key))
    {
      log_error ("LOG_VEC_PAGE: key %lu is not a vector index.  Skipping the record.",
	  (unsigned long) key_id);
      vvec_replay_condemn (key_id);
      return 1;
    }
  kf = key->key_fragments ? key->key_fragments[0] : NULL;
  it = kf ? kf->kf_it : NULL;
  if (!it || !it->it_storage)
    {
      log_error ("Vector index %s: no index tree to replay into.  Skipping the record and "
	  "rebuilding the graph from the stored embeddings instead.",
	  key->key_name ? key->key_name : "(unnamed)");
      vvec_replay_condemn (key_id);
      return 1;
    }
  /* Restoring into a rebuilt database: DP describes the original allocation, so
     none of the checks below, which all read it as a local page number, apply.
     Its errors are reported and dropped here rather than returned, for the same
     reason as every other path out of this function. */
  if (f_read_from_rebuilt_database)
    {
      caddr_t err = NULL;
      if (vvec_restore_replay_page (it, key, key_id, dp, offset, bytes, len, is_new_page, &err))
	return 1;
      log_error ("Vector index %s: could not relocate the image of page %lu into the rebuilt "
	  "database (%s: %s).  Skipping the record and rebuilding the graph from the stored "
	  "embeddings instead.",
	  key->key_name ? key->key_name : "(unnamed)", (unsigned long) dp,
	  err && ERR_STATE (err) ? ERR_STATE (err) : "?",
	  err && ERR_MESSAGE (err) ? ERR_MESSAGE (err) : "no detail");
      dk_free_tree (err);
      vvec_replay_condemn (key_id);
      return 1;
    }
  if (!IT_PAGE_IN_RANGE (it, dp))
    {
      log_error ("Vector index %s: the log has an image for page %lu, which is outside the "
	  "storage extent.  Skipping the record and rebuilding the graph from the stored "
	  "embeddings instead.",
	  key->key_name ? key->key_name : "(unnamed)", (unsigned long) dp);
      vvec_replay_condemn (key_id);
      return 1;
    }
  if (dbs_is_free_page (it->it_storage, dp))
    {
	/* A new page must be represented by a complete, self-identifying image;
	   a delta cannot initialize storage. */
	if (!is_new_page || len < DP_DATA
	    || DPF_VEC != SHORT_REF (bytes + DP_FLAGS)
	    || (key_id_t) LONG_REF (bytes + DP_KEY_ID) != key_id)
	  {
	    log_error ("Vector index %s: page %lu is free and the record is not a full DPF_VEC "
		"image, so there is nothing to initialize it from.  Skipping the record and "
		"rebuilding the graph from the stored embeddings instead.",
		key->key_name ? key->key_name : "(unnamed)", (unsigned long) dp);
	    vvec_replay_condemn (key_id);
	    return 1;
	  }
	/* Page numbers are global, not per-relation, so verify that the checkpoint
	   extent ownership agrees with the vector tree, then reserve the exact
	   page in BOTH allocator layers.
	   Merely calling dbs_page_allocated () sets only the storage free bit;
	   em_new_dp () can then allocate the same page again from ext_pages[]. */
	if (DBS_DP_TO_EM (it->it_storage, dp) != it->it_extent_map)
	  {
	    log_error ("Vector index %s: page %lu is not in the index's extent map.  Skipping "
		"the record and rebuilding the graph from the stored embeddings instead.",
		key->key_name ? key->key_name : "(unnamed)", (unsigned long) dp);
	    vvec_replay_condemn (key_id);
	    return 1;
	  }
	ITC_INIT (itc, it->itc_commit_space, NULL);
	itc_from_it (itc, it);
	buf = it_new_page_exact (it, dp, DPF_VEC);
	if (!buf)
	  {
	    log_error ("Vector index %s: could not reserve page %lu for replay.  Skipping the "
		"record and rebuilding the graph from the stored embeddings instead.",
		key->key_name ? key->key_name : "(unnamed)", (unsigned long) dp);
	    vvec_replay_condemn (key_id);
	    return 1;
	  }
	/* it_new_page_exact () zeroed the page, so the record's own bytes are all
	   that has to be written: the tail it left out is already what it said. */
	memcpy (buf->bd_buffer, bytes, len);
	vvec_page_release (itc, buf);
	return 1;
    }
  /* The page is allocated as far as the free map is concerned, so it has to be
     read before it can be judged -- and reading it is the dangerous part.
     DPF_INDEX is 0 (widisk.h), so a page of zeroes IS a B-tree page to
     buf_disk_read (): it calls pg_make_map (), which finds key id 0 and hits
     insert.c:163.  With assertion_on_read_fail set that is GPF_T1 -- the
     process dies inside page_wait_access (), before any check here can run.

     A page can be allocated and blank across a crash: the free map is
     checkpoint state, and an allocation that reached the checkpointed map
     without its content reaching disk leaves the bit set over zeroes.  That is
     a leaked allocation rather than another tree's data -- live data would
     have its own flags and key id and would read back intact -- but the only
     way to establish which it is, is to look, so the read has to be survivable
     first.  Clearing the assertion turns the GPF into a log line and an empty
     content map; col.c:4730 does the same thing for the same reason.  Restore
     it on every path out: replay is single-threaded, running from log_init ()
     before the server listens, but it is still a global. */
  /* A LOG_VEC_PAGE record names an absolute page, and a page number is not a
     stable name for a page.  Allocation is not itself logged -- roll forward
     re-allocates as a side effect of replaying rows -- so between the record
     being written and this replay reaching it, the page can have gone to
     another tree.  Measured: a vector index's page number reappearing as a
     page of an ordinary table in the same checkpoint interval.

     Write nothing in that case.  Overwriting would corrupt whichever tree owns
     the page now, which is worse than anything the record could fix, and
     skipping is recoverable: the embeddings are an ordinary logged table that
     has rolled forward with everything else, so vvec_epoch_reconcile ()
     rebuilds the graph from them on first use -- the behaviour this index had
     before LOG_VEC_PAGE existed.  Replay continues either way; one unusable
     record is not a reason to refuse to start a database. */
  if (!vvec_replay_page_is_ours (it, dp, key_id))
    {
      vvec_replay_condemn (key_id);
      log_error ("Vector index %s: the log has an image for page %lu, but that page is no "
	  "longer the index's.  Skipping the record and rebuilding the graph from the stored "
	  "embeddings instead.",
	  key->key_name ? key->key_name : "(unnamed)", (unsigned long) dp);
      return 1;
    }
  ITC_INIT (itc, it->itc_commit_space, NULL);
  itc_from_it (itc, it);
  /* The record names this page; nothing has vouched for its contents yet -- that
     is what the DP_FLAGS/DP_KEY_ID check below is for.  A page allocated after
     the last checkpoint reads back as zeros, and DPF_INDEX is 0, so the generic
     read path takes it for an index page and pg_make_map () kills the server on
     the unresolvable key id rather than letting us refuse it.  Read it the way
     db_crash_to_log () reads pages it cannot vouch for either. */
  {
    int saved_assertion_on_read_fail = assertion_on_read_fail;
    assertion_on_read_fail = 0;
    vvec_page_access (itc, dp, PA_WRITE, &buf);
    assertion_on_read_fail = saved_assertion_on_read_fail;
  }
  if (!buf)
    {
      log_error ("Vector index %s: page %lu could not be read for replay.  Skipping the "
	  "record and rebuilding the graph from the stored embeddings instead.",
	  key->key_name ? key->key_name : "(unnamed)", (unsigned long) dp);
      vvec_replay_condemn (key_id);
      return 1;
    }
  if (DPF_VEC != SHORT_REF (buf->bd_buffer + DP_FLAGS)
      || (key_id_t) LONG_REF (buf->bd_buffer + DP_KEY_ID) != key_id)
    {
      /* Belt and braces: vvec_replay_page_is_ours () just said otherwise, so
	 reaching this means the page changed hands underneath us. */
      vvec_page_release (itc, buf);
      log_error ("Vector index %s: page %lu is not the index's, refusing to overwrite it.  "
	  "Skipping the record and rebuilding the graph from the stored embeddings instead.",
	  key->key_name ? key->key_name : "(unnamed)", (unsigned long) dp);
      vvec_replay_condemn (key_id);
      return 1;
    }
  buf = vvec_page_delta (itc, buf);
  memcpy (buf->bd_buffer + offset, bytes, len);
  /* A new-page record describes a whole page, trailing zeroes included.
     Reaching here means the allocator already had the page, so its tail holds
     whatever was there rather than the zeroes the record implies.  Clear it, so
     that the page ends up identical whichever branch applied the record. */
  if (is_new_page && len < PAGE_SZ)
    memset (buf->bd_buffer + len, 0, PAGE_SZ - len);
  vvec_page_release (itc, buf);
  return 1;
}


/* Leave a page the backup walk only read.  vvec_page_release () would now do
   the same thing -- it logs only pages the transaction is recorded as having
   written, and the walk writes none -- but going straight to
   page_leave_outside_map () says so at the call site: this walk emits each
   page's full image itself, and nothing about it belongs to the WAL delta
   path. */
static void
vvec_backup_leave (buffer_desc_t * buf)
{
  page_leave_outside_map (buf);
}


static int
vvec_backup_one_page (lock_trx_t * lt, key_id_t key_id, buffer_desc_t * buf, int * n_ret)
{
  int lte;
  log_vec_page (lt, key_id, buf->bd_page, 0, buf->bd_buffer, PAGE_SZ);
  lte = lt_backup_flush (lt, 1);
  if (LTE_OK != lte)
    {
      log_error ("Could not write vector index page %ld to the dump, error %d",
	  (long) buf->bd_page, lte);
      return 0;
    }
  (*n_ret)++;
  return 1;
}


static int
vvec_backup_overflow (it_cursor_t * itc, lock_trx_t * lt, key_id_t key_id,
    dp_addr_t head, int * n_ret)
{
  while (head)
    {
      buffer_desc_t * ov = NULL;
      int ok;
      vvec_page_access (itc, head, PA_READ, &ov);
      if (!ov)
	return 0;
      ok = vvec_backup_one_page (lt, key_id, ov, n_ret);
      head = ok ? (dp_addr_t) vvec_meta_ref_i32 (ov, VVEC_OV_NEXT_DP) : 0;
      vvec_backup_leave (ov);
      if (!ok)
	return 0;
    }
  return 1;
}


/* Dump one vector index's graph as whole-page LOG_VEC_PAGE records, the same
   record normal WAL logging emits for a newly allocated page.  walk_db () cannot
   carry the graph itself: it is a logical dump and a DPF_VEC page holds no rows.
   Restore relocates these pages, so the numbers written here do not have to be
   free in the target database.  Every page of a graph is reachable from the root
   -- the invariant vvec_graph_reset () already relies on to free them all -- so
   walking the node chain and its overflow chains is complete.
   Returns the number of pages dumped, or -1 if the log could not take them. */
int
vvec_backup_pages (lock_trx_t * lt, index_tree_t * it)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * root = NULL;
  vvec_node_ref_t next;
  key_id_t key_id;
  int n_pages = 0;
  int ok;

  if (!it || !it->it_key || !it->it_root)
    return 0;
  key_id = it->it_key->key_id;
  ITC_INIT (itc, NULL, lt);
  itc_from_it (itc, it);
  vvec_root_read (itc, it, PA_READ, &root);
  if (!root)
    return -1;
  next = (vvec_node_ref_t) vvec_meta_ref_i32 (root, VVEC_META_NODE_HEAD);
  ok = vvec_backup_one_page (lt, key_id, root, &n_pages);
  vvec_backup_leave (root);
  if (!ok)
    return -1;
  while (next)
    {
      buffer_desc_t * node = NULL;
      dp_addr_t ov_next = 0;
      vvec_page_access (itc, VVEC_NREF_PAGE (next), PA_READ, &node);
      if (!node)
	return -1;
      ok = vvec_backup_one_page (lt, key_id, node, &n_pages);
      if (VVEC_ROLE_PACKED == vvec_page_role (node))
	{
	  int nc = vvec_pk_node_count (node), s;
	  for (s = 0; ok && s < nc; s++)
	    {
	      db_buf_t cn = vvec_pk_node_ptr (node, s);
	      if (cn && vvec_cn_has_overflow (cn))
		ok = vvec_backup_overflow (itc, lt, key_id, vvec_cn_overflow_head (cn), &n_pages);
	    }
	  next = (vvec_node_ref_t) LONG_REF (node->bd_buffer + VVEC_PK_NEXT_DP) << VVEC_NREF_SLOT_BITS;
	}
      else
	{
	  next = (vvec_node_ref_t) vvec_meta_ref_i32 (node, VVEC_NODE_NEXT_DP);
	  if (vvec_node_has_overflow (node))
	    ov_next = vvec_node_overflow_head (node, vvec_meta_ref_i32 (node, VVEC_NODE_HNSW_M));
	}
      vvec_backup_leave (node);
      if (ok && ov_next)
	ok = vvec_backup_overflow (itc, lt, key_id, ov_next, &n_pages);
      if (!ok)
	return -1;
    }
  return n_pages;
}


/* Frees the per-transaction before-image hash populated by vvec_page_delta ()
   -- see the field comment on lock_trx_t::lt_vvec_page_images in ltrx.h.
   Called from lt_free ()/lt_clear () (lock.c) alongside blob_log_set_free (),
   the analogous per-transaction log-state cleanup for blobs. A no-op if this
   transaction never touched a vector index page.

   Takes the field rather than its value, and clears it.  lt_clear () does not
   destroy a transaction, it empties one for the NEXT transaction of the same
   connection to use, so a pointer left behind here is not a tidiness problem:
   the next transaction finds it non-NULL, skips allocating, and reads and
   writes freed memory for as long as the connection lives. */
void
vvec_page_images_free (dk_hash_64_t ** images_ret)
{
  dk_hash_64_t * images = images_ret ? *images_ret : NULL;
  id_hash_iterator_t hit;
  caddr_t key_buf, val_buf;
  if (!images)
    return;
  *images_ret = NULL;
  id_hash_iterator (&hit, images);
  while (hit_next (&hit, &key_buf, &val_buf))
    {
      int64 have = *(int64 *) val_buf;
      /* VVEC_PAGE_IMAGE_NEW is a marker, not a pointer -- a page allocated by
	 a transaction that then died with it still in flight. */
      if (have && VVEC_PAGE_IMAGE_NEW != have)
	dk_free ((caddr_t) (ptrlong) have, PAGE_SZ);
    }
  hash_table_free_64 (images);
}


int
vvec_key_source_match (dbe_key_t * key, const char *source_col_name, const char **pk_col_name_ret, int *metric_ret)
{
  caddr_t metric_box;
  char * source_col;
  if (pk_col_name_ret)
    *pk_col_name_ret = NULL;
  if (metric_ret)
    *metric_ret = 0;
  if (!source_col_name || !vvec_key_ready (key))
    return 0;
  source_col = (char *) vvec_opt_value (key->key_options, VVEC_OPT_SOURCE_COLUMN);
  if (!source_col || stricmp (source_col, source_col_name))
    return 0;
  if (pk_col_name_ret)
    *pk_col_name_ret = (const char *) vvec_opt_value (key->key_options, VVEC_OPT_PK_COLUMN);
  if (metric_ret)
    {
      metric_box = vvec_opt_value (key->key_options, VVEC_OPT_DISTANCE);
      *metric_ret = vvec_parse_metric (vvec_is_string_box (metric_box) ? (char *) metric_box : NULL);
    }
  return 1;
}


/* Optimizer rewrites must only target indexes that the runtime can resolve and
 * use.  This prevents a stale schema object from compiling into a VEC01 path. */
static int
vvec_key_ready (dbe_key_t * key)
{
  char * state;
  if (!vvec_key_p (key) || key->key_is_dropped || !key->key_name || !key->key_table)
    return 0;
  state = (char *) vvec_opt_value (key->key_options, VVEC_OPT_STATE);
  if (!state ||
      (stricmp (state, VVEC_STATE_READY_FOR_INTERNAL_LOAD) && stricmp (state, VVEC_STATE_READY)))
    return 0;
  return NULL != vvec_opt_value (key->key_options, VVEC_OPT_HIDDEN_TABLE);
}


static dbe_key_t *
vvec_find_key_by_name (const char *index_name)
{
  dbe_key_t * found = NULL;
  if (!index_name || !wi_inst.wi_schema)
    return NULL;
  DO_HT (ptrlong, id, dbe_key_t *, key, wi_inst.wi_schema->sc_id_to_key)
    {
      (void) id;
      if (key && key->key_name && !strcmp (key->key_name, index_name))
	{
	  found = key;
	  break;
	}
    }
  END_DO_HT;
  return found;
}


int
vvec_explain_index_info (const char *index_name, const char *mode, char *buf, int buflen)
{
  dbe_key_t * key;
  caddr_t * opts;
  const char * source_col;
  const char * pk_col;
  caddr_t metric_box;
  int dim = 0, hnsw_m = 0, ef_constr = 0, model_id = 0;
  int metric;
  const char * table_name;
  const char * metric_name_s;

  if (!index_name || !buf || buflen <= 0)
    return 0;
  buf[0] = 0;
  key = vvec_find_key_by_name (index_name);
  if (!vvec_key_p (key))
    return 0;
  opts = key->key_options;
  source_col = (const char *) vvec_opt_value (opts, VVEC_OPT_SOURCE_COLUMN);
  pk_col = (const char *) vvec_opt_value (opts, VVEC_OPT_PK_COLUMN);
  metric_box = vvec_opt_value (opts, VVEC_OPT_DISTANCE);
  metric = vvec_parse_metric (vvec_is_string_box (metric_box) ? (char *) metric_box : NULL);
  metric_name_s = vvec_metric_name (metric);
  if (!vvec_opt_int_value (opts, VVEC_OPT_DIMENSIONS, 0, &dim))
    dim = 0;
  if (!vvec_opt_int_value (opts, VVEC_OPT_HNSW_M, 0, &hnsw_m))
    hnsw_m = 0;
  if (!vvec_opt_int_value (opts, VVEC_OPT_EF_CONSTR, 0, &ef_constr))
    ef_constr = 0;
  if (!vvec_opt_int_value (opts, VVEC_OPT_MODEL_ID, 0, &model_id))
    model_id = 0;
  table_name = (key->key_table && key->key_table->tb_name) ? key->key_table->tb_name : "?";

  snprintf (buf, (size_t) buflen,
      "vector index %s: source=%s pk=%s table=%s model_id=%d metric=%s dim=%d hnsw_m=%d ef_construction=%d mode=%s",
      index_name,
      source_col ? source_col : "?",
      pk_col ? pk_col : "?",
      table_name,
      model_id,
      metric_name_s ? metric_name_s : "?",
      dim,
      hnsw_m,
      ef_constr,
      mode ? mode : "row_distance");
  return 1;
}


int
vvec_explain_row_distance_info (const char *index_name, char *buf, int buflen)
{
  return vvec_explain_index_info (index_name, "row_distance", buf, buflen);
}


static caddr_t
vvec_opts_append_val (caddr_t * opts, const char *name, caddr_t val)
{
  caddr_t * v_opts;
  const char * short_name;
  int inx, len;
  v_opts = vvec_vector_opts (opts);
  short_name = vvec_map_opt_name (name);
  if (!opts || DV_ARRAY_OF_POINTER != DV_TYPE_OF (opts))
    return (caddr_t) opts;
  if (v_opts && DV_ARRAY_OF_POINTER != DV_TYPE_OF (v_opts))
    v_opts = NULL;
  if (!v_opts)
    {
      v_opts = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      v_opts[0] = box_dv_short_string (short_name);
      v_opts[1] = val;
      opts = (caddr_t *) box_append_1_free ((caddr_t) opts, (caddr_t) OPT_VECTOR);
      opts = (caddr_t *) box_append_1_free ((caddr_t) opts, (caddr_t) v_opts);
      return (caddr_t) opts;
    }
  
  len = BOX_ELEMENTS (v_opts);
  for (inx = 0; inx < len - 1; inx += 2)
    {
      if (vvec_is_string_box (v_opts[inx]) && !stricmp (vvec_map_opt_name ((char *) v_opts[inx]), short_name))
	{
	  v_opts[inx + 1] = val;
	  return (caddr_t) opts;
	}
    }

  v_opts = (caddr_t *) box_append_1_free ((caddr_t) v_opts, box_dv_short_string (short_name));
  v_opts = (caddr_t *) box_append_1_free ((caddr_t) v_opts, val);
  /* Need to find OPT_VECTOR in opts and replace its value */
  len = BOX_ELEMENTS (opts);
  for (inx = 0; inx < len - 1; inx++)
    {
      if (vvec_opt_slot_is (opts[inx], OPT_VECTOR))
	{
	  opts[inx + 1] = (caddr_t) v_opts;
	  break;
	}
    }
  return (caddr_t) opts;
}


/* The precomputed-vector ("bring your own vectors") passthrough column mode is
 * gated behind the __vvec_passthrough_column registry flag so it can be disabled
 * without a code revert during stabilization.  Returns 1 only when the flag is
 * explicitly 'on'.  registry_get () asserts the transaction mutex is held
 * (ASSERT_IN_TXN, regist.c) -- being inside a transaction is not the same
 * thing -- so take it for the read, as every other caller does. */
static int
vvec_passthrough_enabled (void)
{
  caddr_t v;
  int on;
  IN_TXN;
  v = registry_get ("__vvec_passthrough_column");
  LEAVE_TXN;
  on = (v && DV_STRINGP (v) && !stricmp ((char *) v, "on")) ? 1 : 0;
  if (v)
    dk_free_tree (v);
  return on;
}


/* Infer the source column for CREATE VECTOR INDEX ... ON <table> written
 * without a ('<column>') list.
 *
 * Deliberately only when the table leaves no choice: exactly one column of the
 * right shape for the source kind.  Both zero and more-than-one are errors, and
 * the more-than-one error names the candidates so the fix is obvious.  Picking
 * one -- the first, the widest, whatever -- would build an expensive index over
 * the wrong column and report success; the mistake would then surface only as
 * quietly bad search results, long after the DDL that caused it.
 */
static dbe_column_t *
vvec_infer_source_column (dbe_table_t * tb, int source_kind, caddr_t name, caddr_t table)
{
  dbe_column_t * found = NULL;
  int n = 0;
  char cands[512];
  cands[0] = 0;
  if (!tb->tb_primary_key)
    sqlr_new_error ("42000", "VEC11",
        "Cannot infer a source column for vector index %.200s: table %.200s has no primary key.", name, table);
  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
    {
      if (!((VVEC_SOURCE_VECTOR == source_kind)
              ? vvec_source_col_is_vector_compatible (col)
              : vvec_source_col_is_string_compatible (col)))
        continue;
      n++;
      if (!found)
        found = col;
      if (col->col_name && strlen (cands) + strlen (col->col_name) + 3 < sizeof (cands))
        {
          if (cands[0])
            strcat (cands, ", ");
          strcat (cands, col->col_name);
        }
    }
  END_DO_SET ();
  if (1 == n)
    return found;
  if (0 == n)
    sqlr_new_error ("42000", "VEC11",
        "Cannot infer a source column for vector index %.200s: table %.200s has no %s column. "
        "Name one explicitly: ON %.200s (<column>).",
        name, table,
        (VVEC_SOURCE_VECTOR == source_kind) ? "vector-compatible" : "string-compatible", table);
  sqlr_new_error ("42000", "VEC11",
      "Cannot infer a source column for vector index %.200s: table %.200s has %d candidates (%.200s). "
      "Name one explicitly: ON %.200s (<column>).",
      name, table, n, cands, table);
  return NULL;
}


caddr_t *
vvec_prepare_index_opts (query_instance_t * qi, caddr_t name, caddr_t table, caddr_t * cols, caddr_t * opts)
{
  caddr_t * res = (caddr_t *) box_copy_tree ((box_t) opts);
  dbe_table_t * tb = qi_name_to_table (qi, table);
  dbe_column_t * source_col = NULL;
  dbe_column_t * pk_col = NULL;
  char * hidden_table;
  caddr_t model, metric_name, dim_text, reduce_text, m_text, ef_text;
  caddr_t source_kind_box;
  int source_kind = VVEC_SOURCE_TEXT;
  int dimension = 0;
  int reduce;
  int hnsw_m;
  int ef_constr;
  int metric;
  int model_id = 0;
  int model_shape_dim = 0;
  local_cursor_t * lc = NULL;
  caddr_t err = NULL;
  query_t * qr;
  if (!tb)
    sqlr_new_error ("42S02", "VEC10", "Cannot find table %.300s in creating vector index %.300s.", table, name);
  if (vvec_tb_is_rdf_obj (tb))
    {
      if (BOX_ELEMENTS (cols) > 1 || (1 == BOX_ELEMENTS (cols) && (!vvec_is_string_box (cols[0]) || stricmp ((char *) cols[0], "RO_VAL"))))
        sqlr_new_error ("42000", "VEC11", "A vector index on DB.DBA.RDF_OBJ indexes the literal value: write ON DB.DBA.RDF_OBJ or ON DB.DBA.RDF_OBJ (RO_VAL).");
      source_col = tb_name_to_column (tb, "RO_VAL");
    }
  else if (0 == (int) BOX_ELEMENTS (cols))
    {
      /* ON <table> with no ('<column>'): the source kind decides what shape of
         column to look for, so it has to be read before the inference. */
      int sk = vvec_parse_source_kind (vvec_opt_value (res, VVEC_OPT_SOURCE_KIND));
      if (sk < 0)
        sqlr_new_error ("42000", "VEC85", "Vector source_kind option must be 'text' or 'vector'.");
      source_col = vvec_infer_source_column (tb, sk, name, table);
    }
  else
    {
      if (1 != (int) BOX_ELEMENTS (cols))
        sqlr_new_error ("42000", "VEC11", "Bootstrap vector indexes currently require exactly one source column.");
      if (!vvec_is_string_box (cols[0]))
        sqlr_new_error ("42000", "VEC11", "Vector index source column must be a named table column.");
      source_col = tb_name_to_column (tb, (char *) cols[0]);
      if (!source_col)
        sqlr_new_error ("42S22", "VEC11", "Cannot find vector source column %.300s on table %.300s.", (char *) cols[0], table);
    }
  source_kind_box = vvec_opt_value (res, VVEC_OPT_SOURCE_KIND);
  source_kind = vvec_parse_source_kind (source_kind_box);
  if (source_kind < 0)
    sqlr_new_error ("42000", "VEC85", "Vector source_kind option must be 'text' or 'vector'.");
  if (vvec_tb_is_rdf_obj (tb))
    {
      if (VVEC_SOURCE_VECTOR == source_kind)
        sqlr_new_error ("42000", "VEC85", "A vector index on DB.DBA.RDF_OBJ embeds literal text; source_kind='vector' is not supported there.");
      source_kind = VVEC_SOURCE_RDF_OBJ;
    }
  else if (VVEC_SOURCE_RDF_OBJ == source_kind)
    sqlr_new_error ("42000", "VEC85", "source_kind='rdf_obj' is only valid for a vector index on DB.DBA.RDF_OBJ.");
  if (VVEC_SOURCE_VECTOR == source_kind && !vvec_passthrough_enabled ())
    sqlr_new_error ("42000", "VEC83",
        "Precomputed-vector passthrough column mode (source_kind='vector') is not enabled. "
        "A DBA can enable it with: registry_set ('__vvec_passthrough_column', 'on').");
  if (VVEC_SOURCE_VECTOR == source_kind)
    {
      if (!vvec_source_col_is_vector_compatible (source_col))
	sqlr_new_error ("42000", "VEC87",
	    "Vector source column %.300s must be ANY, LONG ANY, or (LONG) VARBINARY for source_kind='vector'.",
	    source_col->col_name);
    }
  else if (!vvec_source_col_is_string_compatible (source_col))
    sqlr_new_error ("42000", "VEC11", "Vector source column %.300s must be a string-compatible column.", source_col->col_name);
  if (!tb->tb_primary_key || tb->tb_primary_key->key_n_significant != 1 || !tb->tb_primary_key->key_parts)
    sqlr_new_error ("42000", "VEC11", "Vector indexes currently require a single-column integer primary key on %.300s.", table);
  pk_col = (dbe_column_t *) tb->tb_primary_key->key_parts->data;
  if (!pk_col)
    sqlr_new_error ("42000", "VEC11", "Vector indexes currently require a single-column integer primary key on %.300s.", table);
  if (!(DV_SHORT_INT == pk_col->col_sqt.sqt_dtp || DV_LONG_INT == pk_col->col_sqt.sqt_dtp || DV_INT64 == pk_col->col_sqt.sqt_dtp || DV_NUMERIC == pk_col->col_sqt.sqt_dtp))
    sqlr_new_error ("42000", "VEC11", "Vector primary key column %.300s must be integer-compatible.", pk_col->col_name);
  model = vvec_opt_value (res, VVEC_OPT_MODEL);
  metric_name = vvec_opt_value (res, VVEC_OPT_DISTANCE);
  dim_text = vvec_opt_value (res, VVEC_OPT_DIMENSIONS);
  reduce_text = vvec_opt_value (res, VVEC_OPT_REDUCE);
  m_text = vvec_opt_value (res, VVEC_OPT_HNSW_M);
  ef_text = vvec_opt_value (res, VVEC_OPT_EF_CONSTR);
  if (-1 == vvec_parse_rebuild (vvec_opt_value (res, VVEC_OPT_REBUILD)))
    sqlr_new_error ("42000", "VEC81", "Vector rebuild option must be 'replay', 'fast' or 'auto'.");
  /* How CREATE builds the graph over the rows already in the table: linked in
     one at a time ('incremental', the default, which 'auto' also means), or
     derived in one pass once every row is embedded ('bulk').  The values
     SPARQL CREATE VECTOR INDEX takes. */
  {
    caddr_t build = vvec_opt_value (res, VVEC_OPT_BUILD);
    if (build && (!vvec_is_string_box (build)
	  || (stricmp ((char *) build, "incremental") && stricmp ((char *) build, "bulk") && stricmp ((char *) build, "auto"))))
      sqlr_new_error ("42000", "VEC81", "Vector build option must be 'incremental', 'bulk' or 'auto'.");
  }
  /* Bring-your-own-vectors passthrough column mode (source_kind='vector') is
   * parsed and gated with the column-type check above; when absent/'text' the
   * model path below is byte-for-byte unchanged.  The remaining checks need the
   * model binding, read just above. */
  if (VVEC_SOURCE_VECTOR == source_kind && model)
    sqlr_new_error ("42000", "VEC84",
        "source_kind='vector' (precomputed vectors) cannot be combined with USING '<model>'; omit the USING clause.");
  if (VVEC_SOURCE_VECTOR != source_kind && !model)
    sqlr_new_error ("42000", "VEC12",
        "Vector indexes require USING '<model>' binding, or WITH (source_kind='vector') for a precomputed-vector column.");
  if (!vvec_parse_reduce (reduce_text, &reduce))
    sqlr_new_error ("42000", "VEC64", "Vector reduce option must be 'none' or 'truncate'.");
  if (VVEC_SOURCE_VECTOR == source_kind && VVEC_REDUCE_TRUNCATE == reduce)
    sqlr_new_error ("42000", "VEC86",
        "reduce='truncate' requires a model and is not supported with source_kind='vector'.");
  if (!dim_text && VVEC_REDUCE_TRUNCATE == reduce)
    sqlr_new_error ("42000", "VEC13", "Vector indexes with reduce='truncate' require WITH (dimensions = <n>).");
  /* WITH (dimensions = <n>) is optional for a model-backed index: the model's
     declared output shape is read from DB.DBA.ONNX_MODELS below, and demanding
     the same number from the user was asking them to repeat a fact the server
     already had -- and would reject them for getting wrong (VEC19).  It stays
     required for reduce='truncate', where the target is a free choice rather
     than a property of the model, and for source_kind='vector', where there is
     no model to ask. */
  if (!dim_text && VVEC_SOURCE_VECTOR == source_kind)
    sqlr_new_error ("42000", "VEC13",
        "Vector indexes with source_kind='vector' require WITH (dimensions = <n>).");
  if (dim_text && !vvec_parse_int_value (dim_text, &dimension))
    sqlr_new_error ("42000", "VEC13", "Vector indexes require WITH (dimensions = <positive integer>).");
  if (m_text)
    {
      if (!vvec_parse_int_value (m_text, &hnsw_m))
	sqlr_new_error ("42000", "VEC16", "Vector hnsw_m must be an integer value.");
    }
  else
    hnsw_m = 16;
  if (ef_text)
    {
      if (!vvec_parse_int_value (ef_text, &ef_constr))
	sqlr_new_error ("42000", "VEC16", "Vector ef_construction must be an integer value.");
    }
  else
    ef_constr = 200;
  int is_string = vvec_is_string_box (metric_name);
  metric = vvec_parse_metric (is_string ? (char *) metric_name : NULL);
  if (!hnsw_m)
    hnsw_m = 16;
  if (!ef_constr)
    ef_constr = 200;
  if (!metric)
    sqlr_new_error ("42000", "VEC14", "Unsupported vector distance metric %s.", vvec_is_string_box (metric_name) ? (char *) metric_name : "<null>");
  if (dim_text && dimension <= 0)
    sqlr_new_error ("42000", "VEC15", "Vector dimension must be greater than zero.");
  if (dimension > (0x7fffffff / (int) sizeof (float)))
    sqlr_new_error ("42000", "VEC15", "Vector dimension is too large.");
  if (hnsw_m <= 0)
    sqlr_new_error ("42000", "VEC16", "Vector hnsw_m must be greater than zero.");
  if (ef_constr <= 0)
    sqlr_new_error ("42000", "VEC16", "Vector ef_construction must be greater than zero.");
  /* a dimension left to the model is 0 here, checked again below */
  if (!VVEC_NODE_FITS_PAGE (hnsw_m, dimension))
    sqlr_new_error ("42000", "VEC17", "Vector storage cannot fit node metadata for hnsw_m=%d.", hnsw_m);
  /* Passthrough (source_kind='vector') has no model: keep model_id = 0 and skip
   * the ONNX_MODELS resolution entirely. */
  if (VVEC_SOURCE_VECTOR != source_kind)
    {
      qr = sql_compile_static ("select model_id, output_shape from DB.DBA.ONNX_MODELS where model_name = ?", qi->qi_client, &err, SQLC_DEFAULT);
      if (err)
	sqlr_resignal (err);
      err = qr_quick_exec (qr, qi->qi_client, "", &lc, 1, ":0", model, QRP_STR);
      if (SQL_SUCCESS != err)
	{
	  qr_free (qr);
	  sqlr_resignal (err);
	}
      if (!lc)
	{
	  qr_free (qr);
	  sqlr_new_error ("42S02", "VEC19", "Failed to execute query for model %s.", (char *) model);
	}
      if (!lc_next (lc))
	{
	  lc_free (lc);
	  qr_free (qr);
	  sqlr_new_error ("42S02", "VEC18", "Model %s is not present in DB.DBA.ONNX_MODELS.", (char *) model);
	}
      caddr_t col0 = lc_nth_col (lc, 0);
      if (!col0)
	{
	  lc_free (lc);
	  qr_free (qr);
	  sqlr_new_error ("42S02", "VEC20", "Model %s has NULL model_id in DB.DBA.ONNX_MODELS.", (char *) model);
	}
      model_id = (int) unbox (col0);
      caddr_t col1 = lc_nth_col (lc, 1);
      if (col1)
	{
	  model_shape_dim = vvec_model_shape_dim ((char *) col1);
	}
      lc_free (lc);
      qr_free (qr);
    }
  if (!dim_text && VVEC_SOURCE_VECTOR != source_kind)
    {
      if (model_shape_dim <= 0)
        sqlr_new_error ("42000", "VEC13",
            "Model %s does not declare an output shape, so this index needs WITH (dimensions = <n>).",
            (char *) model);
      dimension = model_shape_dim;
      if (dimension <= 0 || dimension > (0x7fffffff / (int) sizeof (float)))
        sqlr_new_error ("42000", "VEC15",
            "Model %s declares an unusable output dimension %d.", (char *) model, dimension);
      if (!VVEC_NODE_FITS_PAGE (hnsw_m, dimension))
        sqlr_new_error ("42000", "VEC17", "Vector storage cannot fit node metadata for hnsw_m=%d.", hnsw_m);
      res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_DIMENSIONS, box_num (dimension));
    }
  if (VVEC_REDUCE_TRUNCATE == reduce && model_shape_dim <= 0)
    sqlr_new_error ("42000", "VEC19", "Model %s output dimension is required for reduce='truncate'.", (char *) model);
  if (VVEC_REDUCE_TRUNCATE == reduce && dimension > model_shape_dim)
    sqlr_new_error ("42000", "VEC19", "Model %s output dimension %d is smaller than requested reduced vector dimension %d.", (char *) model, model_shape_dim, dimension);
  if (VVEC_REDUCE_TRUNCATE != reduce && model_shape_dim && model_shape_dim != dimension)
    sqlr_new_error ("42000", "VEC19", "Model %s output dimension %d does not match requested vector dimension %d.", (char *) model, model_shape_dim, dimension);
  if (!ef_text)
    {
      res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_EF_CONSTR, box_num (ef_constr));
    }
  if (!m_text)
    {
      res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_HNSW_M, box_num (hnsw_m));
    }
  if (!metric_name)
    {
      res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_DISTANCE, box_dv_short_string ("cosine"));
    }
  if (reduce_text)
    {
      res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_REDUCE, box_dv_short_string ((char *) vvec_reduce_name (reduce)));
    }
  if (VVEC_REDUCE_TRUNCATE == reduce)
    res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_NATIVE_DIMENSIONS, box_num (model_shape_dim));
  res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_SOURCE_COLUMN, box_dv_short_string (source_col->col_name));
  res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_PK_COLUMN, box_dv_short_string (pk_col->col_name));
  res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_MODEL_ID, box_num (model_id));
  /* Canonicalize source_kind='vector' into the stored key options under "sk".
   * Nothing is appended for the default TEXT path, so a model index's stored
   * options stay byte-for-byte identical to before this feature. */
  if (VVEC_SOURCE_VECTOR == source_kind)
    res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_SOURCE_KIND, box_dv_short_string ("vector"));
  else if (VVEC_SOURCE_RDF_OBJ == source_kind)
    res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_SOURCE_KIND, box_dv_short_string ("rdf_obj"));
  hidden_table = vvec_hidden_table_name (tb, name);
  res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_HIDDEN_TABLE, box_dv_short_string (hidden_table));
  dk_free_tree ((caddr_t) hidden_table);
  res = (caddr_t *) vvec_opts_append_val ((caddr_t *) res, VVEC_OPT_STATE, box_dv_short_string (VVEC_STATE_READY_FOR_INTERNAL_LOAD));
  return res;
}


void
vvec_key_open_init_root (index_tree_t * it, dbe_key_t * key)
{
  it_map_t * itm;
  buffer_desc_t * buf;
  caddr_t metric_box = vvec_opt_value (key->key_options, VVEC_OPT_DISTANCE);
  int dimension = 0;
  int metric = vvec_parse_metric (vvec_is_string_box (metric_box) ? (char *) metric_box : NULL);
  int hnsw_m = 16;
  int ef_constr = 200;
  int model_id = 0;
  if (!vvec_opt_int_value (key->key_options, VVEC_OPT_DIMENSIONS, 0, &dimension))
    dimension = 0;
  if (!vvec_opt_int_value (key->key_options, VVEC_OPT_HNSW_M, 16, &hnsw_m))
    hnsw_m = 16;
  if (!vvec_opt_int_value (key->key_options, VVEC_OPT_EF_CONSTR, 200, &ef_constr))
    ef_constr = 200;
  if (!vvec_opt_int_value (key->key_options, VVEC_OPT_MODEL_ID, 0, &model_id))
    model_id = 0;
  buf = it_new_vec_page (it, 0, 0);
  memset (buf->bd_buffer + DP_DATA, 0, PAGE_SZ - DP_DATA);
  vvec_meta_set_i32 (buf, VVEC_META_MAGIC, VVEC_MAGIC);
  vvec_meta_set_i32 (buf, VVEC_META_ROLE, VVEC_ROLE_META);
  vvec_meta_set_i32 (buf, VVEC_META_VERSION, VVEC_VERSION);
  vvec_meta_set_i32 (buf, VVEC_META_DIM, dimension);
  vvec_meta_set_i32 (buf, VVEC_META_METRIC, metric);
  vvec_meta_set_i32 (buf, VVEC_META_HNSW_M, hnsw_m);
  vvec_meta_set_i32 (buf, VVEC_META_EF_CONSTR, ef_constr);
  vvec_meta_set_i32 (buf, VVEC_META_MODEL_ID, model_id);
  vvec_meta_set_i32 (buf, VVEC_META_ENTRY_DP, 0);
  vvec_meta_set_i32 (buf, VVEC_META_NODE_HEAD, 0);
  vvec_meta_set_i32 (buf, VVEC_META_MAX_LAYER, 0);
  LONG_SET (buf->bd_buffer + DP_PARENT, 0);
  SHORT_SET (buf->bd_buffer + DP_RIGHT_INSERTS, 0);
  SHORT_SET (buf->bd_buffer + DP_LAST_INSERT, VVEC_VERSION);
  it->it_root = buf->bd_page;
  itm = IT_DP_MAP (it, buf->bd_page);
  mutex_enter (&itm->itm_mtx);
  page_leave_inner (buf);
  mutex_leave (&itm->itm_mtx);
}


static int
vvec_trigger_exists (query_instance_t * qi, dbe_table_t * tb, const char *trigger_name)
{
  caddr_t err = NULL;
  local_cursor_t * lc = NULL;
  query_t * qr;
  int ret = 0;
  qr = sql_compile_static ("select count (*) from DB.DBA.SYS_TRIGGERS where T_TABLE = ? and name_part (T_NAME, 2) = ?", qi->qi_client, &err, SQLC_DEFAULT);
  if (err)
    sqlr_resignal (err);
  err = qr_quick_exec (qr, qi->qi_client, "", &lc, 2,
      ":0", tb->tb_name, QRP_STR,
      ":1", (char *) trigger_name, QRP_STR);
  if (SQL_SUCCESS != err)
    {
      qr_free (qr);
      sqlr_resignal (err);
    }
  if (lc && lc_next (lc))
    ret = 0 != unbox (lc_nth_col (lc, 0));
  if (lc)
    lc_free (lc);
  qr_free (qr);
  return ret;
}


static void
vvec_drop_trigger_if_exists (query_instance_t * qi, dbe_table_t * tb, const char *trigger_name)
{
  char * trigger_q;
  char text[1024];
  if (!tb || !vvec_trigger_exists (qi, tb, trigger_name))
    return;
  trigger_q = vvec_quote_trigger_qname (tb, trigger_name);
  snprintf (text, sizeof (text), "drop trigger %s", trigger_q);
  vvec_exec_text (qi, text);
  dk_free_box ((box_t) trigger_q);
}


static void
vvec_create_dml_triggers (query_instance_t * qi, caddr_t table, caddr_t name, caddr_t * opts)
{
  dbe_table_t * tb = qi_name_to_table (qi, table);
  char * source_col = (char *) vvec_opt_value (opts, VVEC_OPT_SOURCE_COLUMN);
  char * pk_col = (char *) vvec_opt_value (opts, VVEC_OPT_PK_COLUMN);
  char trig_i[MAX_NAME_LEN * 3];
  char trig_u[MAX_NAME_LEN * 3];
  char trig_d[MAX_NAME_LEN * 3];
  char * table_q;
  char * trig_i_q;
  char * trig_u_q;
  char * trig_d_q;
  char * source_q;
  char * pk_q;
  char * index_lit;
  char * text;
  size_t text_len;
  if (!tb || !source_col || !pk_col)
    sqlr_new_error ("42000", "VEC22", "Vector index %s missing DML trigger metadata.", name);
  vvec_trigger_short_name (trig_i, sizeof (trig_i), name, "VVEC_AI");
  vvec_trigger_short_name (trig_u, sizeof (trig_u), name, "VVEC_AU");
  vvec_trigger_short_name (trig_d, sizeof (trig_d), name, "VVEC_AD");
  table_q = vvec_quote_qname (tb->tb_name);
  trig_i_q = vvec_quote_ident (trig_i);
  trig_u_q = vvec_quote_ident (trig_u);
  trig_d_q = vvec_quote_ident (trig_d);
  source_q = vvec_quote_ident (source_col);
  pk_q = vvec_quote_ident (pk_col);
  index_lit = vvec_quote_sql_literal (name);
  text_len = strlen (table_q) + strlen (trig_i_q) + strlen (trig_u_q) + strlen (trig_d_q) +
      (4 * strlen (source_q)) + (5 * strlen (pk_q)) + (3 * strlen (index_lit)) + 2048;
  text = (char *) dk_alloc_box (text_len, DV_STRING);
  snprintf (text, text_len,
      "create trigger %s after insert on %s order 199 referencing new as N\n"
      "{\n"
      "  DB.DBA.VEC_SQL_QUEUE_ENQUEUE (%s, N.%s, 'upsert');\n"
      "}",
      trig_i_q, table_q, index_lit, pk_q);
  vvec_exec_text (qi, text);
  snprintf (text, text_len,
      "create trigger %s after update (%s, %s) on %s order 199 referencing old as O, new as N\n"
      "{\n"
      "  if (O.%s <> N.%s)\n"
      "    DB.DBA.VEC_SQL_QUEUE_ENQUEUE (%s, O.%s, 'delete');\n"
      "  DB.DBA.VEC_SQL_QUEUE_ENQUEUE (%s, N.%s, 'upsert');\n"
      "}",
      trig_u_q, source_q, pk_q, table_q, pk_q, pk_q, index_lit, pk_q, index_lit, pk_q);
  vvec_exec_text (qi, text);
  snprintf (text, text_len,
      "create trigger %s after delete on %s order 199 referencing old as O\n"
      "{\n"
      "  DB.DBA.VEC_SQL_QUEUE_ENQUEUE (%s, O.%s, 'delete');\n"
      "}",
      trig_d_q, table_q, index_lit, pk_q);
  vvec_exec_text (qi, text);
  dk_free_box ((box_t) text);
  dk_free_box ((box_t) table_q);
  dk_free_box ((box_t) trig_i_q);
  dk_free_box ((box_t) trig_u_q);
  dk_free_box ((box_t) trig_d_q);
  dk_free_box ((box_t) source_q);
  dk_free_box ((box_t) pk_q);
  dk_free_box ((box_t) index_lit);
}


static void
vvec_backfill_existing_rows (query_instance_t * qi, caddr_t table, caddr_t name, caddr_t * opts)
{
  dbe_table_t * tb = qi_name_to_table (qi, table);
  char * pk_col = (char *) vvec_opt_value (opts, VVEC_OPT_PK_COLUMN);
  char * index_lit;
  char sql[2048];

  if (!tb || !pk_col)
    sqlr_new_error ("42000", "VEC24", "Vector index %s missing backfill metadata.", (char *) name);

  index_lit = vvec_quote_sql_literal (name);
  /* DML triggers only enqueue; CREATE VECTOR INDEX is an index-build operation, so it drains
   * the queued backfill rows before returning to preserve create-then-searchable semantics. */
  snprintf (sql, sizeof (sql), "select DB.DBA.VEC_SQL_QUEUE_BACKFILL (%s)", index_lit);
  vvec_exec_text (qi, sql);
  dk_free_box ((box_t) index_lit);
}


/* The DDL wrapper also attempts cleanup, but post-create work can create SQL
 * objects before it raises.  Tear those down while the vector key is still
 * resolvable, then let the original failure reach the caller. */
static void
vvec_cleanup_failed_post_create (query_instance_t * qi, caddr_t table, caddr_t name)
{
  char * index_lit = vvec_quote_sql_literal (name);
  char sql[1024];
  QR_RESET_CTX_T (qi->qi_thread)
    {
      snprintf (sql, sizeof (sql), "delete from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = %s", index_lit);
      vvec_exec_text_ignore_error (qi, sql);
      snprintf (sql, sizeof (sql), "delete from DB.DBA.VEC_SQL_QUEUE_LOCK where VL_INDEX = %s", index_lit);
      vvec_exec_text_ignore_error (qi, sql);
      if (sch_table_key (wi_inst.wi_schema, table, name, 1))
        ddl_drop_index ((caddr_t *) qi, table, name, 0);
    }
  QR_RESET_CODE
    {
      caddr_t cleanup_err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      dk_free_tree (cleanup_err);
    }
  END_QR_RESET;
  dk_free_box ((box_t) index_lit);
}


/* Vision rule 3/4: the hidden embedding table is server-managed -- public DML
 * must not inject arbitrary vectors into a model-bound index.  Every legitimate
 * write goes through a DBA context: the DBA-only BIFs (__VEC_INDEX_INSERT_EMBEDDING,
 * __VEC_INDEX_EMBED_AND_INSERT, ...) and the async queue worker
 * (VEC_SQL_QUEUE_PROCESS_ONE), which also drives those DBA-only BIFs.  So BEFORE
 * INSERT/UPDATE/DELETE guards that reject a non-DBA writer close the direct-write
 * hole (e.g. INSERT INTO <index>_vec_embeddings ... by the base table's owner)
 * without ever blocking a legitimate embedding write.
 *
 * The guards live on the hidden table, so vvec_drop_index's `drop table <hidden>`
 * removes them automatically -- no separate teardown.  Residual: the base table's
 * owner owns the hidden table and could DROP these guards; that is a deliberate
 * circumvention, not the accidental mixed-model contamination rule 3 targets. */
static void
vvec_create_hidden_guard_triggers (query_instance_t * qi, const char *index_name, const char *hidden)
{
  static const char * suffixes[3] = { "VVEC_GI", "VVEC_GU", "VVEC_GD" };
  static const char * events[3]   = { "insert", "update", "delete" };
  int i;
  for (i = 0; i < 3; i++)
    {
      char trig[MAX_NAME_LEN * 3];
      char * trig_q;
      char text[2048];
      vvec_trigger_short_name (trig, sizeof (trig), index_name, suffixes[i]);
      trig_q = vvec_quote_ident (trig);
      /* A before-trigger that signals aborts the offending statement.  user_is_dba
         (the current session user) is the same test the SPARQL vector layer uses.
         The hidden table is referenced UNQUOTED (raw), exactly as the CREATE TABLE
         and every other hidden-table reference does, so the name folds identically
         under any CaseMode.  Quoting it here (case-sensitive) broke under
         CaseMode=1, where the unquoted CREATE folds the mixed-case name (the
         "_vec_embeddings" suffix is lower-case) to upper while the quoted trigger
         reference kept mixed case -> SQ090 "Bad table ... in trigger definition". */
      snprintf (text, sizeof (text),
          "create trigger %s before %s on %s\n"
          "{\n"
          "  if (not user_is_dba (user))\n"
          "    signal ('42000', 'Direct %s of vector index embedding table is not permitted; "
          "embeddings are server-managed. Write the base table or use a DBA embedding BIF.', 'VEC82');\n"
          "}",
          trig_q, events[i], hidden, events[i]);
      vvec_exec_text (qi, text);
      dk_free_box ((box_t) trig_q);
    }
}


void
vvec_index_post_create (query_instance_t * qi, caddr_t table, caddr_t name, caddr_t * opts)
{
  char * hidden = vvec_opt_value (opts, VVEC_OPT_HIDDEN_TABLE);
  char text[2048];
  QR_RESET_CTX_T (qi->qi_thread)
    {
      if (!hidden)
        sqlr_new_error ("42000", "VEC21", "Vector index %s missing hidden table metadata.", name);
      if (!sch_table_key (wi_inst.wi_schema, table, name, 1))
        sqlr_new_error ("42S12", "VEC20", "Cannot find newly created vector index %s.", name);
      snprintf (text, sizeof (text),
          "create table %s (VE_D_ID BIGINT PRIMARY KEY, VE_EMBEDDING LONG ANY, SOURCE_HASH VARCHAR(32), "
          "EMBED_STATUS VARCHAR(32), MODEL_ID INTEGER, UPDATED_AT DATETIME)",
          hidden);
      vvec_exec_text (qi, text);
      vvec_create_hidden_guard_triggers (qi, name, hidden);
      if (VVEC_SOURCE_RDF_OBJ == vvec_parse_source_kind (vvec_opt_value (opts, VVEC_OPT_SOURCE_KIND)))
        {
          /* RDF_OBJ is written with triggers off by the bulk loader, so changes come through
             RDF_OBJ_VEC_LOG instead, and the build is RDF_OBJ_VEC_INDEX_REFRESH, not a drain in DDL. */
          char * index_lit = vvec_quote_sql_literal (name);
          snprintf (text, sizeof (text), "DB.DBA.RDF_OBJ_VEC_INDEX_REGISTER (%s)", index_lit);
          dk_free_box ((box_t) index_lit);
          vvec_exec_text (qi, text);
        }
      else
        {
          vvec_create_dml_triggers (qi, table, name, opts);
          vvec_backfill_existing_rows (qi, table, name, opts);
        }
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_cleanup_failed_post_create (qi, table, name);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  /* snprintf (index_name, sizeof (index_name), "%s_NODE_DP", safe_index);
   snprintf (text, sizeof (text), "create unique index %s on %s (node_dp)", index_name, hidden);
   vvec_exec_text (qi, text); */
}


static void vvec_undo_forget (query_instance_t * qi, vvec_meta_t * meta, index_tree_t * it);

void
vvec_drop_index (query_instance_t * qi, dbe_key_t * key)
{
  char * hidden = vvec_opt_value (key->key_options, VVEC_OPT_HIDDEN_TABLE);
  char trig_i[MAX_NAME_LEN * 3];
  char trig_u[MAX_NAME_LEN * 3];
  char trig_d[MAX_NAME_LEN * 3];
  char text[1024];
  if (key)                       /* perf phase 2: free the in-memory arena */
    {
      index_tree_t * it = key->key_fragments && key->key_fragments[0] ? key->key_fragments[0]->kf_it : NULL;
      dk_mutex_t * wmtx = vvec_writer_lock (it);
      vvec_arena_drop (key->key_id);
      vvec_undo_forget (NULL, NULL, it);
      vvec_writer_unlock (wmtx);
      vvec_forget_key_id (qi, key->key_id);
    }
  if (key && key->key_table)
    {
      vvec_trigger_short_name (trig_i, sizeof (trig_i), key->key_name, "VVEC_AI");
      vvec_trigger_short_name (trig_u, sizeof (trig_u), key->key_name, "VVEC_AU");
      vvec_trigger_short_name (trig_d, sizeof (trig_d), key->key_name, "VVEC_AD");
      vvec_drop_trigger_if_exists (qi, key->key_table, trig_i);
      vvec_drop_trigger_if_exists (qi, key->key_table, trig_u);
      vvec_drop_trigger_if_exists (qi, key->key_table, trig_d);
    }
  if (key && VVEC_SOURCE_RDF_OBJ == vvec_parse_source_kind (vvec_opt_value (key->key_options, VVEC_OPT_SOURCE_KIND)))
    {
      char * index_lit = vvec_quote_sql_literal (key->key_name);
      snprintf (text, sizeof (text), "DB.DBA.RDF_OBJ_VEC_INDEX_UNREGISTER (%s)", index_lit);
      dk_free_box ((box_t) index_lit);
      vvec_exec_text_ignore_error (qi, text);
    }
  if (hidden)
    {
      /* Drop unconditionally with error tolerance instead of guarding on
         sch_name_to_table(hidden): that C-API lookup is case-sensitive and
         misses the table under CaseMode=1, where the table is stored
         upper-folded while the stored metadata name keeps the mixed-case
         "_vec_embeddings" suffix.  Missing it orphaned the hidden table and its
         guard triggers on DROP.  The unquoted "drop table" folds the name per
         CaseMode and finds it; ignore_error tolerates an already-absent table. */
      snprintf (text, sizeof (text), "drop table %s", hidden);
      vvec_exec_text_ignore_error (qi, text);
    }
}


/* Has this dp already been freed by this walk?  Claims it if not.
 *
 * A chain with a cycle, a self-reference or a duplicate overflow head reaches
 * the same page twice, and the second visit frees an already-freed page.  The
 * root is claimed before the walk starts for the same reason: a chain pointing
 * back at it would free it here and the drop caller would free it again. */
static int
vvec_chain_claim (dk_hash_64_t * seen, dp_addr_t dp)
{
  int64 have = 0;
  gethash_64 (have, (int64) dp, seen);
  if (have)
    return 0;
  sethash_64 ((int64) dp, seen, 1);
  return 1;
}


/* Is BUF a page of this index at all?  Every vvec page stamps VVEC_MAGIC at
   DP_DATA+0 and its role at DP_DATA+4, so one test covers meta, node, packed
   and overflow; the caller checks the role it expects. */
static int
vvec_chain_page_ok (dbe_key_t * key, buffer_desc_t * buf)
{
  if (!buf || DPF_VEC != SHORT_REF (buf->bd_buffer + DP_FLAGS))
    return 0;
  if (key && (key_id_t) LONG_REF (buf->bd_buffer + DP_KEY_ID) != key->key_id)
    return 0;
  return VVEC_MAGIC == vvec_meta_ref_i32 (buf, VVEC_NODE_MAGIC);
}


/* Free one overflow chain, stopping at the first page that is not this index's
   own overflow page.  Validated exactly as strictly as the node chain: these
   references come off a page that may itself be damaged, and an unchecked free
   here hands another index's page back to the free set. */
static void
vvec_free_overflow_chain (it_cursor_t * itc, index_tree_t * it, dbe_key_t * key,
    dk_hash_64_t * seen, dp_addr_t next, const char * kname)
{
  while (next)
    {
      buffer_desc_t * ov = NULL;
      dp_addr_t cur = next;
      if (!IT_PAGE_IN_RANGE (it, cur) || !vvec_chain_claim (seen, cur))
	{
	  log_error ("Vector index %s: overflow chain reaches page %lu, which is out of range or "
	      "already freed by this walk. Abandoning the rest of the chain.", kname, (unsigned long) cur);
	  return;
	}
      vvec_page_access (itc, cur, PA_WRITE, &ov);
      if (!vvec_chain_page_ok (key, ov) || VVEC_ROLE_OVERFLOW != vvec_page_role (ov))
	{
	  if (ov)
	    vvec_page_release (itc, ov);
	  log_error ("Vector index %s: overflow chain reaches page %lu, which is not one of its "
	      "overflow pages. Abandoning the rest of the chain.", kname, (unsigned long) cur);
	  return;
	}
      ov = vvec_page_delta (itc, ov);
      next = vvec_meta_ref_i32 (ov, VVEC_OV_NEXT_DP);
      vvec_page_free (itc, it, ov);
    }
}


/* Free every page the node chain reaches, leaving only the root.
 *
 * Shared by the rebuild (vvec_graph_reset) and the drop (vvec_key_dropped).
 * The drop needs it because nothing else ever gives these pages back:
 * dbs_cpt_extents () reclaims a dropped tree's inventory wholesale only for a
 * tree that owns its extent map, and a vector index deliberately stays on the
 * shared one (c15d53b169).  Freeing here returns each page to the map it was
 * allocated from, so no promotion and no per-page lookup is involved.
 *
 * Every reference is validated before it is followed and every page is claimed
 * before it is freed.  Both callers walk a chain nobody has vouched for -- a
 * rebuild runs on a graph already known to be damaged, and a drop can follow any
 * crash -- and the cost of getting it wrong is freeing a page that belongs to
 * something else, or freeing one of these twice. */
static void
vvec_free_node_chain (it_cursor_t * itc, index_tree_t * it, dbe_key_t * key,
    buffer_desc_t * root, int hnsw_m)
{
  /* id_hash_allocate () memsets ht_rehash_threshold to 0 and ID_CHECK_REHASH is
     a no-op at 0, so a table made here never grows: every caller that can hold
     more than a handful of entries has to opt in, as sqlcost.c:1401, meta.c:71
     and clrdf.c:629 do.  Without it this walk is quadratic in the number of
     graph pages -- a chain left by incremental inserts is one page per node,
     so on a multi-million-node graph the 61 buckets alone cost hours. */
  dk_hash_64_t * seen = hash_table_allocate_64 (65536);
  id_hash_set_rehash_pct (seen, 120);
  const char * kname = (key && key->key_name) ? key->key_name : "<unknown>";
  vvec_node_ref_t next = (vvec_node_ref_t) vvec_meta_ref_i32 (root, VVEC_META_NODE_HEAD);
  vvec_chain_claim (seen, root->bd_page);
  while (next)
    {
      buffer_desc_t * node = NULL;
      dp_addr_t page_dp = VVEC_NREF_PAGE (next);
      int role;
      if (!IT_PAGE_IN_RANGE (it, page_dp) || !vvec_chain_claim (seen, page_dp))
	{
	  log_error ("Vector index %s: the graph's node chain reaches page %lu, which is out of "
	      "range or already freed by this walk. Abandoning the rest of it; its pages stay "
	      "allocated.", kname, (unsigned long) page_dp);
	  break;
	}
      vvec_page_access (itc, page_dp, PA_WRITE, &node);
      role = node ? vvec_page_role (node) : 0;
      if (!vvec_chain_page_ok (key, node) || (VVEC_ROLE_NODE != role && VVEC_ROLE_PACKED != role))
	{
	  if (node)
	    vvec_page_release (itc, node);
	  log_error ("Vector index %s: the graph's node chain reaches page %lu, which is not one of "
	      "its node pages. Abandoning the rest of it; its pages stay allocated.",
	      kname, (unsigned long) page_dp);
	  break;
	}
      node = vvec_page_delta (itc, node);
      if (VVEC_ROLE_PACKED == role)
	{
	  int nc = vvec_pk_node_count (node);
	  int slot;
	  for (slot = 0; slot < nc; slot++)
	    {
	      db_buf_t cn = vvec_pk_node_ptr (node, slot);
	      if (cn && vvec_cn_has_overflow (cn))
		vvec_free_overflow_chain (itc, it, key, seen, vvec_cn_overflow_head (cn), kname);
	    }
	  next = (vvec_node_ref_t) LONG_REF (node->bd_buffer + VVEC_PK_NEXT_DP) << VVEC_NREF_SLOT_BITS;
	  vvec_page_free (itc, it, node);
	}
      else
	{
	  dp_addr_t ov_head = vvec_node_has_overflow (node) ? vvec_node_overflow_head (node, hnsw_m) : 0;
	  next = (vvec_node_ref_t) vvec_meta_ref_i32 (node, VVEC_NODE_NEXT_DP);
	  vvec_page_free (itc, it, node);
	  vvec_free_overflow_chain (itc, it, key, seen, ov_head, kname);
	}
    }
  hash_table_free_64 (seen);
}


void
vvec_key_dropped (dbe_key_t * key)
{
  unsigned int inx;
  if (key->key_supers)
    return;
  DO_BOX (dbe_key_frag_t *, kf, inx, key->key_fragments)
    {
      it_cursor_t itc_auto;
      it_cursor_t * itc = &itc_auto;
      buffer_desc_t * root = NULL;
      dbe_storage_t * dbs;
      if (!kf || !kf->kf_it || !kf->kf_it->it_root)
	continue;
      ITC_INIT (itc, kf->kf_it->itc_commit_space, NULL);
      itc_from_it (itc, kf->kf_it);
      dbs = kf->kf_it->it_storage;
      vvec_root_read (itc, kf->kf_it, PA_WRITE, &root);
      root = vvec_page_delta (itc, root);
      /* Everything the graph reaches, then the root.  Checkpoint does not
       * finalize these: see vvec_free_node_chain ().  hnsw_m comes off the root
       * rather than the key options because it has to describe the graph being
       * freed, not what the index is configured for. */
      vvec_free_node_chain (itc, kf->kf_it, key, root,
          vvec_meta_ref_i32 (root, VVEC_META_HNSW_M));
      vvec_page_free (itc, kf->kf_it, root);
      if (kf->kf_it->it_extent_map != kf->kf_it->it_storage->dbs_extent_map)
	{
	  char name[1000];
	  snprintf (name, sizeof (name), "__EM:%s", kf->kf_name);
	  IN_TXN;
	  dbs_registry_set (dbs, name, NULL, 0);
	  LEAVE_TXN;
	}
      IN_TXN;
      dbs_registry_set (dbs, kf->kf_name, NULL, 0);
      dk_set_delete (&dbs->dbs_trees, kf->kf_it);
      dk_set_push (&dbs->dbs_deleted_trees, kf->kf_it);
      kf->kf_it->it_root = 0;
      key->key_is_dropped = 1;
      LEAVE_TXN;
    }
  END_DO_BOX;
}


/* Set or clear the deleted flag on a node's overflow chain; returns the pages changed. */
static int
vvec_mark_overflow_deleted (it_cursor_t * itc, vvec_meta_t * meta, buffer_desc_t * node, int deleted)
{
  dp_addr_t next;
  int pages = 0;
  if (!vvec_node_has_overflow (node))
    return 0;
  next = vvec_node_overflow_head (node, meta->vm_hnsw_m);
  while (next)
    {
      buffer_desc_t * ov = NULL;
      int flags;
      dp_addr_t cur = next;
      vvec_page_access (itc, cur, PA_WRITE, &ov);
      ov = vvec_page_delta (itc, ov);
      if (vvec_meta_ref_i32 (ov, VVEC_OV_MAGIC) != VVEC_MAGIC
	  || vvec_meta_ref_i32 (ov, VVEC_OV_ROLE) != VVEC_ROLE_OVERFLOW)
	{
	  vvec_page_release (itc, ov);
	  sqlr_new_error ("42000", "VEC60", "Corrupt vector overflow page %ld.", (long) cur);
	}
      next = vvec_meta_ref_i32 (ov, VVEC_OV_NEXT_DP);
      flags = vvec_meta_ref_i32 (ov, VVEC_OV_FLAGS);
      if (deleted != !!(flags & VVEC_OVERFLOW_DELETED))
	{
	  vvec_meta_set_i32 (ov, VVEC_OV_FLAGS, deleted ? flags | VVEC_OVERFLOW_DELETED : flags & ~VVEC_OVERFLOW_DELETED);
	  pages++;
	}
      vvec_page_release (itc, ov);
    }
  return pages;
}


static caddr_t
vvec_mark_node_deleted_1 (query_instance_t * qi, vvec_meta_t * meta, vvec_node_ref_t nref, int epoch_delta)
{
  buffer_desc_t * buf = NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  int overflow_deleted;
  dp_addr_t page_dp = VVEC_NREF_PAGE (nref);
  int slot = VVEC_NREF_SLOT (nref);
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);
  vvec_page_access (itc, page_dp, PA_WRITE, &buf);
  buf = vvec_page_delta (itc, buf);
  if (vvec_page_role (buf) == VVEC_ROLE_PACKED)
    {
      /* Phase 4: packed page — set deleted flag in compact node. */
      db_buf_t cn = vvec_pk_node_ptr (buf, slot);
      if (!cn || vvec_cn_is_deleted (cn))
	{
	  vvec_page_release (itc, buf);
	  return box_num (0);
	}
      cn[VVEC_CN_FLAGS] |= VVEC_NODE_DELETED;
      /* Note: overflow deletion for packed nodes not yet implemented. */
      overflow_deleted = 0;
      if (meta->vm_key)
	vvec_arena_mark_deleted (meta->vm_key->key_id, nref, 1);
      vvec_page_release (itc, buf);
    }
  else
    {
      if (vvec_node_is_deleted (buf))
	{
	  vvec_page_release (itc, buf);
	  return box_num (0);
	}
      overflow_deleted = vvec_mark_overflow_deleted (itc, meta, buf, 1);
      vvec_node_set_deleted (buf);
      if (meta->vm_key)
	vvec_arena_mark_deleted (meta->vm_key->key_id, nref, 1);
      vvec_page_release (itc, buf);
    }
  vvec_page_access (itc, meta->vm_it->it_root, PA_WRITE, &buf);
  buf = vvec_page_delta (itc, buf);
  vvec_meta_inc_i64 (buf, VVEC_META_DELETED_NODES, 1);
  vvec_meta_inc_i64 (buf, VVEC_META_ACTIVE_NODES, -1);
  vvec_meta_inc_i64 (buf, VVEC_META_EPOCH, epoch_delta);
  if (overflow_deleted)
    vvec_meta_inc_i64 (buf, VVEC_META_DELETED_OVERFLOW_PAGES, overflow_deleted);
  vvec_page_release (itc, buf);
  return box_num (1);
}


/* The exact inverse of vvec_mark_node_deleted_1 (.., 1): a soft delete only sets
   flags, and nothing reclaims a deleted node or its overflow before a rebuild. */
static int
vvec_undelete_node (query_instance_t * qi, vvec_meta_t * meta, vvec_node_ref_t nref)
{
  buffer_desc_t * buf = NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  int overflow_live = 0;
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);
  vvec_page_access (itc, VVEC_NREF_PAGE (nref), PA_WRITE, &buf);
  buf = vvec_page_delta (itc, buf);
  if (vvec_page_role (buf) == VVEC_ROLE_PACKED)
    {
      db_buf_t cn = vvec_pk_node_ptr (buf, VVEC_NREF_SLOT (nref));
      if (!cn || !vvec_cn_is_deleted (cn))
	{
	  vvec_page_release (itc, buf);
	  return 0;
	}
      cn[VVEC_CN_FLAGS] &= ~VVEC_NODE_DELETED;
    }
  else
    {
      if (!vvec_node_is_deleted (buf))
	{
	  vvec_page_release (itc, buf);
	  return 0;
	}
      overflow_live = vvec_mark_overflow_deleted (itc, meta, buf, 0);
      vvec_meta_set_i32 (buf, VVEC_NODE_FLAGS, vvec_meta_ref_i32 (buf, VVEC_NODE_FLAGS) & ~VVEC_NODE_DELETED);
    }
  if (meta->vm_key)
    vvec_arena_mark_deleted (meta->vm_key->key_id, nref, 0);
  vvec_page_release (itc, buf);
  vvec_page_access (itc, meta->vm_it->it_root, PA_WRITE, &buf);
  buf = vvec_page_delta (itc, buf);
  vvec_meta_inc_i64 (buf, VVEC_META_DELETED_NODES, -1);
  vvec_meta_inc_i64 (buf, VVEC_META_ACTIVE_NODES, 1);
  vvec_meta_inc_i64 (buf, VVEC_META_EPOCH, -1);
  if (overflow_live)
    vvec_meta_inc_i64 (buf, VVEC_META_DELETED_OVERFLOW_PAGES, -overflow_live);
  vvec_page_release (itc, buf);
  return 1;
}


/* Graph changes of rolled-back transactions.

   The graph pages are not transactional, so a rollback leaves the nodes it
   inserted and the soft deletes it made in the graph, while their embedding
   rows and catalog epoch go.  Each transaction lists what it did to which
   index (lt_vvec_undo); a rollback moves that list here, and the next writer
   of the index undoes it, newest first, under the writer lock and before its
   own change -- so the epoch it syncs describes a graph that matches the data.
   A rebuild or drop bumps the index's generation, making earlier entries void:
   the nodes they name are gone.

   Redo has the same gap: the rollback discards the transaction's LOG_VEC_PAGE
   records while the pages keep its bytes, and later deltas may point into
   them.  So a rollback logs one marker per index, and the next writer logs the
   page (and overflow chain) of each rolled-back insert, its backlink targets,
   deleted nodes, and the root whole, then a resync marker, then undoes.  A
   packed or full neighbour list can replace a link, so replaying only the new
   nodes would lose the changes to existing pages.  Replay applies
   everything; an index whose marker is not followed by a resync -- a crash
   before the next write -- is rebuilt from its embeddings. */

#define VVEC_UNDO_INSERT 1
#define VVEC_UNDO_DELETE 2

typedef struct vvec_undo_s
{
  oid_t			vu_key;
  vvec_node_ref_t	vu_nref;
  int			vu_op;
  int64			vu_seq;
  int64			vu_gen;
  dk_set_t		vu_backlink_pages;
} vvec_undo_t;

/* The caller holds the index's writer mutex. */
static void
vvec_undo_note (query_instance_t * qi, vvec_meta_t * meta, int op, vvec_node_ref_t nref)
{
  lock_trx_t * lt = qi->qi_trx;
  vvec_undo_t * vu;
  if (!lt || !meta->vm_key || !meta->vm_it || !nref)
    return;
  vu = (vvec_undo_t *) dk_alloc (sizeof (vvec_undo_t));
  vu->vu_key = meta->vm_key->key_id;
  vu->vu_nref = nref;
  vu->vu_op = op;
  vu->vu_seq = ++meta->vm_it->it_vvec.vt_rb_seq;
  vu->vu_gen = meta->vm_it->it_vvec.vt_rb_gen;
  vu->vu_backlink_pages = NULL;
  /* Captured now: later inserts can replace this node's links, not the backlinks it wrote. */
  if (VVEC_UNDO_INSERT == op)
    {
      it_cursor_t itc_auto;
      it_cursor_t * itc = &itc_auto;
      buffer_desc_t * node = NULL;
      int layer, inx;
      ITC_INIT (itc, NULL, lt);
      itc_from_it (itc, meta->vm_it);
      vvec_page_access (itc, VVEC_NREF_PAGE (nref), PA_READ, &node);
      if (node)
	{
	  int max_layer = vvec_meta_ref_i32 (node, VVEC_NODE_MAX_LAYER);
	  int * counts = vvec_node_counts_ptr (node);
	  for (layer = 0; layer <= max_layer; layer++)
	    {
	      vvec_node_ref_t * links = (vvec_node_ref_t *) vvec_node_layer_ptr (node, meta->vm_hnsw_m, layer);
	      for (inx = 0; inx < counts[layer]; inx++)
		{
		  void * dp = DP_ADDR2VOID (VVEC_NREF_PAGE (links[inx]));
		  if (!dk_set_member (vu->vu_backlink_pages, dp))
		    dk_set_push (&vu->vu_backlink_pages, dp);
		}
	    }
	  page_leave_outside_map (node);
	}
    }
  mutex_enter (lt->lt_log_mtx);
  dk_set_push (&lt->lt_vvec_undo, (void *) vu);
  mutex_leave (lt->lt_log_mtx);
}


static void
vvec_undo_free_one (vvec_undo_t * vu)
{
  dk_set_free (vu->vu_backlink_pages);
  dk_free ((caddr_t) vu, sizeof (vvec_undo_t));
}

#define VVEC_UNDO_LIST_FREE(undo) \
  while (undo) vvec_undo_free_one ((vvec_undo_t *) dk_set_pop (&(undo)))

#define VVEC_RB_MARKER(ses, key_id, offset) \
  log_vec_page_record ((ses), (key_id_t) (key_id), 0, (offset), NULL, 0)


/* Take this index's pending undo out.  The caller holds the writer mutex. */
static dk_set_t
vvec_rb_take (index_tree_t * it, int * marked_ret, int64 * gen_ret, int bump_gen)
{
  vvec_tree_t * vt = &it->it_vvec;
  dk_set_t undo = vt->vt_undo;
  vt->vt_undo = NULL;
  *marked_ret = vt->vt_rb_marked;
  vt->vt_rb_marked = 0;
  *gen_ret = vt->vt_rb_gen;
  if (bump_gen)
    vt->vt_rb_gen++;
  return undo;
}


static void
vvec_rb_page_image (dk_session_t * ses, it_cursor_t * itc, oid_t key_id, dp_addr_t dp, dp_addr_t * next_ov_ret)
{
  buffer_desc_t * buf = NULL;
  *next_ov_ret = 0;
  vvec_page_access (itc, dp, PA_READ, &buf);
  if (!buf)
    return;
  if (DPF_VEC == SHORT_REF (buf->bd_buffer + DP_FLAGS)
      && (oid_t) LONG_REF (buf->bd_buffer + DP_KEY_ID) == key_id
      && VVEC_ROLE_OVERFLOW == vvec_meta_ref_i32 (buf, VVEC_OV_ROLE))
    {
      log_vec_page_record (ses, (key_id_t) key_id, dp, VVEC_LOG_NEW_PAGE,
	  buf->bd_buffer, vvec_page_image_len (buf->bd_buffer));
      *next_ov_ret = (dp_addr_t) vvec_meta_ref_i32 (buf, VVEC_OV_NEXT_DP);
    }
  page_leave_outside_map (buf);
}


/* Log the rolled-back changes' node, overflow, neighbour and root pages whole, then the resync marker. */
static void
vvec_rb_resync (query_instance_t * qi, vvec_meta_t * meta, dk_set_t undo, int marked, int64 gen)
{
  dk_session_t * ses;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  dk_hash_t * seen;
  dk_hash_t * affected;
  oid_t key_id = meta->vm_key->key_id;
  if (!marked)
    return;
  ses = strses_allocate ();
  seen = hash_table_allocate (31);
  affected = hash_table_allocate (31);
  sethash (DP_ADDR2VOID (meta->vm_it->it_root), affected, (void *) 1);
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);
  DO_SET (vvec_undo_t *, vu, &undo)
    {
      dp_addr_t dp = VVEC_NREF_PAGE (vu->vu_nref);
      buffer_desc_t * node = NULL;
      dp_addr_t ov = 0;
      if (vu->vu_gen != gen)
	continue;
      sethash (DP_ADDR2VOID (dp), affected, (void *) 1);
      DO_SET (void *, neighbor_dp, &vu->vu_backlink_pages)
	sethash (neighbor_dp, affected, (void *) 1);
      END_DO_SET ();
      vvec_page_access (itc, dp, PA_READ, &node);
      if (!node)
	continue;
      if (DPF_VEC == SHORT_REF (node->bd_buffer + DP_FLAGS)
	  && (oid_t) LONG_REF (node->bd_buffer + DP_KEY_ID) == key_id)
	{
	  if (VVEC_ROLE_NODE == vvec_page_role (node))
	    {
	      if (vvec_node_has_overflow (node))
		ov = vvec_node_overflow_head (node, meta->vm_hnsw_m);
	    }
	}
      page_leave_outside_map (node);
      while (ov && !gethash (DP_ADDR2VOID (ov), seen))
	{
	  dp_addr_t cur = ov;
	  sethash (DP_ADDR2VOID (cur), seen, (void *) 1);
	  vvec_rb_page_image (ses, itc, key_id, cur, &ov);
	}
    }
  END_DO_SET ();
  DO_HT (ptrlong, page_no, void *, ignored, affected)
    {
      buffer_desc_t * page = NULL;
      dp_addr_t dp = (dp_addr_t) page_no;
      vvec_page_access (itc, dp, PA_READ, &page);
      if (page)
	{
	  if (DPF_VEC == SHORT_REF (page->bd_buffer + DP_FLAGS)
	      && (oid_t) LONG_REF (page->bd_buffer + DP_KEY_ID) == key_id)
	    log_vec_page_record (ses, (key_id_t) key_id, dp, VVEC_LOG_NEW_PAGE,
		page->bd_buffer, vvec_page_image_len (page->bd_buffer));
	  page_leave_outside_map (page);
	}
    }
  END_DO_HT;
  hash_table_free (affected);
  hash_table_free (seen);
  VVEC_RB_MARKER (ses, key_id, VVEC_LOG_ROLLBACK_RESYNC);
  if (LTE_OK != log_vec_page_sync (qi->qi_trx, ses))
    log_error ("Vector index %s: could not log the pages of a rolled-back transaction; "
	"a crash before the next checkpoint rebuilds the index.",
	meta->vm_key->key_name ? meta->vm_key->key_name : "<unknown>");
  strses_free (ses);
}


/* Drop what rolled-back transactions left, for a graph that is about to be
   rebuilt (QI given, under the writer mutex, so its markers are closed first)
   or dropped.  The rebuilding transaction's own items go too: they name nodes
   of the old graph, and its rollback must not wait for the writer mutex that
   this same thread holds across the rebuild's commits. */
static void
vvec_undo_forget (query_instance_t * qi, vvec_meta_t * meta, index_tree_t * it)
{
  int64 gen;
  int marked;
  dk_set_t undo;
  if (!it)
    return;
  undo = vvec_rb_take (it, &marked, &gen, 1);
  if (qi && qi->qi_trx && meta && meta->vm_key)
    {
      lock_trx_t * lt = qi->qi_trx;
      dk_set_t keep = NULL;
      mutex_enter (lt->lt_log_mtx);
      while (lt->lt_vvec_undo)
	{
	  vvec_undo_t * vu = (vvec_undo_t *) dk_set_pop (&lt->lt_vvec_undo);
	  if (vu->vu_key == meta->vm_key->key_id)
	    vvec_undo_free_one (vu);
	  else
	    dk_set_push (&keep, (void *) vu);
	}
      lt->lt_vvec_undo = dk_set_nreverse (keep);
      mutex_leave (lt->lt_log_mtx);
    }
  if (qi && meta)
    vvec_rb_resync (qi, meta, undo, marked, gen);
  VVEC_UNDO_LIST_FREE (undo);
}


void
vvec_trx_rollback (lock_trx_t * lt)
{
  dk_set_t undo;
  int logged = lt->lt_replicate != REPL_NO_LOG && !cl_non_logged_write_mode;
  mutex_enter (lt->lt_log_mtx);
  undo = lt->lt_vvec_undo;
  lt->lt_vvec_undo = NULL;
  mutex_leave (lt->lt_log_mtx);
  if (!undo)
    return;
  if (logged)
    {
      dk_session_t * ses = strses_allocate ();
      dk_hash_t * marked = hash_table_allocate (11);
      DO_SET (vvec_undo_t *, vu, &undo)
	{
	  if (gethash (DP_ADDR2VOID (vu->vu_key), marked))
	    continue;
	  sethash (DP_ADDR2VOID (vu->vu_key), marked, (void *) 1);
	  VVEC_RB_MARKER (ses, vu->vu_key, VVEC_LOG_ROLLBACK_MARK);
	}
      END_DO_SET ();
      if (LTE_OK != log_vec_page_sync (lt, ses))
	log_error ("Could not log that a rolled-back transaction changed vector index pages; "
	    "roll forward may not reproduce those indexes exactly.");
      strses_free (ses);
      hash_table_free (marked);
    }
  while (undo)
    {
      vvec_undo_t * vu = (vvec_undo_t *) dk_set_pop (&undo);
      oid_t key_id = vu->vu_key;
      dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, key_id);
      index_tree_t * it = key && vvec_key_p (key) && key->key_fragments && key->key_fragments[0]
	  ? key->key_fragments[0]->kf_it : NULL;
      dk_set_t mine = NULL, rest = NULL;
      dk_mutex_t * wmtx;
      dk_set_push (&mine, (void *) vu);
      while (undo)
	{
	  vvec_undo_t * other = (vvec_undo_t *) dk_set_pop (&undo);
	  dk_set_push (other->vu_key == key_id ? &mine : &rest, (void *) other);
	}
      undo = dk_set_nreverse (rest);
      if (!it)
	{
	  VVEC_UNDO_LIST_FREE (mine);
	  continue;
	}
      wmtx = vvec_writer_lock (it);
      it->it_vvec.vt_rb_marked |= logged;
      while (mine)
	dk_set_push (&it->it_vvec.vt_undo, dk_set_pop (&mine));
      vvec_writer_unlock (wmtx);
    }
}


void
vvec_trx_undo_free (lock_trx_t * lt)
{
  VVEC_UNDO_LIST_FREE (lt->lt_vvec_undo);
}


void
vvec_tree_free (vvec_tree_t * vt)
{
  VVEC_UNDO_LIST_FREE (vt->vt_undo);
  /* it_temp_allocate () trees never had these initialized. */
  if (!vt->vt_graph_rwlock)
    return;
  rwlock_free (vt->vt_graph_rwlock);
  dk_mutex_destroy (&vt->vt_writer_mtx);
}


static int
vvec_undo_seq_desc (const void * a, const void * b)
{
  int64 sa = (*(vvec_undo_t **) a)->vu_seq, sb = (*(vvec_undo_t **) b)->vu_seq;
  return sa < sb ? 1 : sa > sb ? -1 : 0;
}


/* Undo what rolled-back transactions left in this index's graph.  The caller
   holds the writer lock.  Returns the number of changes undone. */
static int
vvec_undo_apply (query_instance_t * qi, vvec_meta_t * meta)
{
  dk_set_t undo;
  vvec_undo_t ** arr;
  int64 gen;
  int marked, n, inx, done = 0;
  if (!meta->vm_key || !meta->vm_it || !meta->vm_it->it_vvec.vt_undo)
    return 0;
  undo = vvec_rb_take (meta->vm_it, &marked, &gen, 0);
  vvec_rb_resync (qi, meta, undo, marked, gen);
  n = dk_set_length (undo);
  arr = (vvec_undo_t **) dk_alloc (n * sizeof (vvec_undo_t *));
  for (inx = 0; inx < n; inx++)
    arr[inx] = (vvec_undo_t *) dk_set_pop (&undo);
  if (n)
    qsort (arr, n, sizeof (vvec_undo_t *), vvec_undo_seq_desc);
  for (inx = 0; inx < n; inx++)
    {
      vvec_undo_t * vu = arr[inx];
      if (vu->vu_gen == gen)
	{
	  if (VVEC_UNDO_INSERT == vu->vu_op)
	    done += (int) unbox (vvec_mark_node_deleted_1 (qi, meta, vu->vu_nref, -1));
	  else
	    done += vvec_undelete_node (qi, meta, vu->vu_nref);
	}
      vvec_undo_free_one (vu);
      arr[inx] = NULL;
    }
  dk_free ((caddr_t) arr, n * sizeof (vvec_undo_t *));
  if (done)
    log_info ("Vector index %s: undid %d graph change(s) of rolled-back transaction(s).",
	meta->vm_key->key_name ? meta->vm_key->key_name : "<unknown>", done);
  return done;
}


/* Rollback markers seen in roll forward, key_id -> 1 until the resync that
   closes them.  Single-threaded: recovery runs before the server listens. */
static dk_hash_t * vvec_replay_rb_open = NULL;

void
vvec_replay_rollback_mark (key_id_t key_id, int offset)
{
  if (VVEC_LOG_ROLLBACK_RESYNC == offset)
    {
      if (vvec_replay_rb_open)
	remhash (DP_ADDR2VOID (key_id), vvec_replay_rb_open);
      return;
    }
  if (!vvec_replay_rb_open)
    vvec_replay_rb_open = hash_table_allocate (11);
  sethash (DP_ADDR2VOID (key_id), vvec_replay_rb_open, (void *) 1);
}


void
vvec_replay_rollback_finish (void)
{
  if (!vvec_replay_rb_open)
    return;
  DO_HT (ptrlong, key_id, void *, ign, vvec_replay_rb_open)
    {
      log_error ("Vector index key %ld: a transaction rolled back after changing its graph and "
	  "the log ends before those pages were logged again; rebuilding it from the stored embeddings.",
	  (long) key_id);
      vvec_replay_condemn ((key_id_t) key_id);
    }
  END_DO_HT;
  hash_table_free (vvec_replay_rb_open);
  vvec_replay_rb_open = NULL;
}


/* A soft delete by a writer, remembered so that a rollback can undo it. */
static void
vvec_delete_node_noted (query_instance_t * qi, vvec_meta_t * meta, vvec_node_ref_t nref, caddr_t * changed_ret)
{
  caddr_t changed = vvec_mark_node_deleted_1 (qi, meta, nref, 1);
  if (unbox (changed))
    vvec_undo_note (qi, meta, VVEC_UNDO_DELETE, nref);
  if (changed_ret)
    *changed_ret = changed;
  else
    dk_free_tree (changed);
}


/* Release every node and overflow page in the graph and return the root to its
   just-created state.  Used by rebuild: the graph is derived data, so the
   cheapest correct repair is to throw it away and replay the embeddings.
   Pages are freed rather than abandoned so a rebuild does not leak the whole
   graph's worth of extents.  */
static void
vvec_graph_reset (query_instance_t * qi, vvec_meta_t * meta)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * root = NULL;
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);
  if (meta->vm_key)
    {
      vvec_arena_drop (meta->vm_key->key_id);
      vvec_undo_forget (qi, meta, meta->vm_it);
    }
  vvec_root_read (itc, meta->vm_it, PA_WRITE, &root);
  root = vvec_page_delta (itc, root);
  vvec_free_node_chain (itc, meta->vm_it, meta->vm_key, root, meta->vm_hnsw_m);
  vvec_meta_set_i32 (root, VVEC_META_ENTRY_DP, 0);
  vvec_meta_set_i32 (root, VVEC_META_NODE_HEAD, 0);
  vvec_meta_set_i32 (root, VVEC_META_MAX_LAYER, 0);
  vvec_meta_set_i64 (root, VVEC_META_TOTAL_NODES, 0);
  vvec_meta_set_i64 (root, VVEC_META_ACTIVE_NODES, 0);
  vvec_meta_set_i64 (root, VVEC_META_DELETED_NODES, 0);
  vvec_meta_set_i64 (root, VVEC_META_OVERFLOW_PAGES, 0);
  vvec_meta_set_i64 (root, VVEC_META_DELETED_OVERFLOW_PAGES, 0);
  /* Bump the epoch the moment the graph is emptied.  data_epoch is only synced
     when the whole rebuild finishes (vvec_epoch_sync), so this keeps graph_epoch
     strictly ahead of data_epoch for the entire rebuild -- including the window
     after reset and before the first insert.  A checkpoint+crash anywhere in that
     window then reconciles as "graph ahead" -> rebuild (vvec_epoch_reconcile),
     instead of trusting an empty or half-built graph.  The only caller is
     vvec_rebuild_impl, under the per-index writer lock. */
  vvec_meta_inc_i64 (root, VVEC_META_EPOCH, 1);
  vvec_page_release (itc, root);
}


/* ===== perf phase 3: bulk rebuild via the in-memory parallel HNSW builder =====
 *
 * Instead of replaying the stored embeddings one at a time through vvec_insert_graph
 * (each doing a page-backed search + link, the ~O(N^1.9) path measured in perf/01),
 * build the whole graph in memory with vvec_hnsw.h (no buffer manager, no per-insert
 * transaction, SIMD distance, optionally multi-threaded) and then serialize it to
 * DPF_VEC pages in two passes. The prototype (perf/proto) measured this ~50x faster
 * single-threaded and ~350x at 10 threads, at equal-or-better recall.
 *
 * Called under the per-index writer lock, after vvec_graph_reset has emptied the
 * graph. The durable embeddings remain the source of truth, so a crash mid-rebuild
 * just leaves the index needing another rebuild -- exactly as today. */

static int
vvec_hm_metric (int vm)
{
  if (VVEC_METRIC_L2 == vm) return VVEC_HM_L2;
  if (VVEC_METRIC_L1 == vm) return VVEC_HM_L1;
  return VVEC_HM_COSINE;
}

/* Phase 4: packed bulk serializer.  Packs multiple compact nodes per
 * DPF_VEC page, reducing storage amplification from ~5.3× to ~1.3× at
 * 384-d/M=16.  Stores only actual neighbors (no pre-allocated slots) and
 * uses 1B layer counts.  Node references use vvec_node_ref_t encoding. */
static void
vvec_bulk_serialize_packed (query_instance_t * qi, vvec_meta_t * meta, vvec_hnsw_t * h, int64 * row_ids)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * root = NULL;
  vvec_node_ref_t * nrefs;
  dp_addr_t * pk_dps;
  int n_pk_pages;
  int n = h->count;
  int i, l, inx;
  int64 overflow_pages = 0;
  int inline_dim = VVEC_DIM_FITS_INLINE (meta->vm_hnsw_m, meta->vm_dimension);
  int dim = meta->vm_dimension;
  int *total_nb_arr;
  int *page_of_node, *slot_of_node;
  int cur_page, cur_slot, cur_offset;
  int *node_count_in_page;
  int max_pages;
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta->vm_it);

  nrefs = (vvec_node_ref_t *) dk_alloc ((size_t) n * sizeof (vvec_node_ref_t));
  total_nb_arr = (int *) dk_alloc ((size_t) n * sizeof (int));
  page_of_node = (int *) dk_alloc ((size_t) n * sizeof (int));
  slot_of_node = (int *) dk_alloc ((size_t) n * sizeof (int));

  /* Pass 0: compute each node's total neighbor count and compact record size. */
  for (i = 0; i < n; i++)
    {
      int total_nb = 0;
      for (l = 0; l <= h->level[i]; l++)
	{
	  int cap = vvec_node_layer_capacity (meta->vm_hnsw_m, l);
	  total_nb += (h->rows[i][l].cnt < cap ? h->rows[i][l].cnt : cap);
	}
      total_nb_arr[i] = total_nb;
    }

  /* Compute page assignment: pack nodes into pages, up to VVEC_NREF_MAX_SLOTS
   * per page, respecting the data area size. */
  cur_page = 0;
  cur_slot = 0;
  cur_offset = 0;
  max_pages = n + 2;
  pk_dps = (dp_addr_t *) dk_alloc ((size_t) max_pages * sizeof (dp_addr_t));
  node_count_in_page = (int *) dk_alloc ((size_t) max_pages * sizeof (int));
  memset (node_count_in_page, 0, (size_t) max_pages * sizeof (int));
  n_pk_pages = 1;

  for (i = 0; i < n; i++)
    {
      int rec_bytes = vvec_cn_record_bytes (dim, h->level[i], total_nb_arr[i], !inline_dim);
      int remaining = VVEC_PK_DATA_USABLE - cur_offset;
      if (cur_slot >= VVEC_NREF_MAX_SLOTS || rec_bytes > remaining)
	{
	  node_count_in_page[cur_page] = cur_slot;
	  cur_page++;
	  cur_slot = 0;
	  cur_offset = 0;
	  n_pk_pages = cur_page + 1;
	}
      page_of_node[i] = cur_page;
      slot_of_node[i] = cur_slot;
      cur_slot++;
      cur_offset += rec_bytes;
      n_pk_pages = cur_page + 1;
    }
  node_count_in_page[cur_page] = cur_slot;

  /* Pass 1: allocate packed pages, initialize headers. */
  for (int pg = 0; pg < n_pk_pages; pg++)
    {
      buffer_desc_t * pkpage = it_new_vec_page (meta->vm_it, meta->vm_it->it_root, itc);
      pk_dps[pg] = pkpage->bd_page;
      LONG_SET (pkpage->bd_buffer + VVEC_PK_MAGIC, VVEC_MAGIC);
      LONG_SET (pkpage->bd_buffer + VVEC_PK_ROLE, VVEC_ROLE_PACKED);
      LONG_SET (pkpage->bd_buffer + VVEC_PK_VERSION, VVEC_VERSION);
      pkpage->bd_buffer[VVEC_PK_NODE_COUNT] = (unsigned char) node_count_in_page[pg];
      LONG_SET (pkpage->bd_buffer + VVEC_PK_NEXT_DP, 0);
      memset (pkpage->bd_buffer + VVEC_PK_DIR_BASE, 0,
	      VVEC_NREF_MAX_SLOTS * VVEC_PK_DIR_ENTRY_BYTES);
      memset (pkpage->bd_buffer + VVEC_PK_DATA_BASE, 0, VVEC_PK_DATA_USABLE);
      vvec_page_release (itc, pkpage);
    }

  for (i = 0; i < n; i++)
    nrefs[i] = VVEC_NREF_MAKE (pk_dps[page_of_node[i]], slot_of_node[i]);

  /* One touch per page: a delta per record would span the directory to the record, re-logging every record before it. */
  i = 0;
  for (int pg = 0; pg < n_pk_pages; pg++)
    {
      buffer_desc_t * pkpage = NULL;
      int offset = 0;
      vvec_page_access (itc, pk_dps[pg], PA_WRITE, &pkpage);
      pkpage = vvec_page_delta (itc, pkpage);
      for (; i < n && page_of_node[i] == pg; i++)
	{
	  int slot = slot_of_node[i];
	  int total_nb = total_nb_arr[i];
	  int rec_bytes = vvec_cn_record_bytes (dim, h->level[i], total_nb, !inline_dim);
	  int dir_off_from_dp = VVEC_PK_HEADER_BYTES + (VVEC_NREF_MAX_SLOTS * VVEC_PK_DIR_ENTRY_BYTES) + offset;
	  int vec_bytes = inline_dim ? (dim * sizeof (float)) : VVEC_NODE_OVERFLOW_REF_BYTES;
	  const float * vec = h->vecs + (size_t) i * dim;
	  vvec_node_ref_t * nb_ptr;
	  db_buf_t cn, vptr;
	  int nb_idx = 0;

	  SHORT_SET (pkpage->bd_buffer + VVEC_PK_DIR_BASE + (slot * VVEC_PK_DIR_ENTRY_BYTES),
		     (uint16) dir_off_from_dp);
	  SHORT_SET (pkpage->bd_buffer + VVEC_PK_DIR_BASE + (slot * VVEC_PK_DIR_ENTRY_BYTES) + 2,
		     (uint16) rec_bytes);

	  cn = pkpage->bd_buffer + DP_DATA + dir_off_from_dp;
	  cn[VVEC_CN_MAX_LAYER] = (unsigned char) h->level[i];
	  cn[VVEC_CN_FLAGS] = 0;
	  SHORT_SET (cn + VVEC_CN_DIM, (uint16) dim);
	  vvec_float_set (cn + VVEC_CN_MAGNITUDE, h->mags[i]);
	  INT64_SET (cn + VVEC_CN_D_ID, row_ids[i]);
	  cn[VVEC_CN_N_LAYERS] = (unsigned char) (h->level[i] + 1);
	  memset (cn + VVEC_CN_COUNTS_BASE, 0, rec_bytes - VVEC_CN_FIXED_BYTES - vec_bytes);

	  nb_ptr = vvec_cn_neighbors_ptr (cn);
	  for (l = 0; l <= h->level[i]; l++)
	    {
	      vh_row_t * r = &h->rows[i][l];
	      int cap = vvec_node_layer_capacity (meta->vm_hnsw_m, l);
	      int keep = r->cnt < cap ? r->cnt : cap;
	      cn[VVEC_CN_COUNTS_BASE + l] = (unsigned char) keep;
	      for (inx = 0; inx < keep; inx++)
		nb_ptr[nb_idx + inx] = nrefs[r->ids[inx]];
	      nb_idx += keep;
	    }

	  vptr = cn + VVEC_CN_FIXED_BYTES + (h->level[i] + 1) + (total_nb * sizeof (vvec_node_ref_t));
	  if (inline_dim)
	    {
	      for (inx = 0; inx < dim; inx++)
		vvec_float_set (vptr + (inx * sizeof (float)), vec[inx]);
	    }
	  else
	    {
	      dp_addr_t ov_head = 0;
	      overflow_pages += vvec_write_overflow_vector (itc, meta, pk_dps[pg], vec, &ov_head);
	      cn[VVEC_CN_FLAGS] |= VVEC_NODE_OVERFLOW;
	      LONG_SET (vptr + VVEC_NODE_OVERFLOW_HEAD_OFF, ov_head);
	      LONG_SET (vptr + VVEC_NODE_OVERFLOW_BYTES_OFF, dim * sizeof (float));
	    }
	  offset += rec_bytes;
	}
      LONG_SET (pkpage->bd_buffer + VVEC_PK_NEXT_DP,
		(pg + 1 < n_pk_pages) ? pk_dps[pg + 1] : 0);
      vvec_page_release (itc, pkpage);
    }

  /* Root: entry point (as nref), chain head, max layer, counters. */
  vvec_root_read (itc, meta->vm_it, PA_WRITE, &root);
  root = vvec_page_delta (itc, root);
  vvec_meta_set_i32 (root, VVEC_META_ENTRY_DP, (int32) nrefs[h->entry]);
  vvec_meta_set_i32 (root, VVEC_META_NODE_HEAD, (int32) VVEC_NREF_MAKE (pk_dps[0], 0));
  vvec_meta_set_i32 (root, VVEC_META_MAX_LAYER, h->max_level);
  vvec_meta_set_i64 (root, VVEC_META_TOTAL_NODES, n);
  vvec_meta_set_i64 (root, VVEC_META_ACTIVE_NODES, n);
  vvec_meta_set_i64 (root, VVEC_META_OVERFLOW_PAGES, overflow_pages);
  vvec_meta_inc_i64 (root, VVEC_META_EPOCH, 1);
  vvec_page_release (itc, root);
  log_info ("Vector index packed: %ld nodes in %d packed pages (%d bytes/node, %.1fx amplification at dim=%d)",
      (long) n, n_pk_pages,
      (int) ((int64) (n_pk_pages + 1) * PAGE_SZ / (n > 0 ? n : 1)),
      (double) ((int64) (n_pk_pages + 1) * PAGE_SZ) / ((double) n * dim * sizeof (float)),
      dim);

  dk_free ((caddr_t) nrefs, (size_t) n * sizeof (vvec_node_ref_t));
  dk_free ((caddr_t) total_nb_arr, (size_t) n * sizeof (int));
  dk_free ((caddr_t) page_of_node, (size_t) n * sizeof (int));
  dk_free ((caddr_t) slot_of_node, (size_t) n * sizeof (int));
  dk_free ((caddr_t) pk_dps, (size_t) n_pk_pages * sizeof (dp_addr_t));
  dk_free ((caddr_t) node_count_in_page, (size_t) max_pages * sizeof (int));
}


/* Build the HNSW in memory from n preloaded (allvec[i], allrow[i]) points and
 * serialize it to pages. The caller owns allvec/allrow and their error cleanup. */
static void
vvec_bulk_build_serialize (query_instance_t * qi, vvec_meta_t * meta,
    const float * allvec, int64 * allrow, int n, int nthreads)
{
  vvec_hnsw_t H;
  int i, dim = meta->vm_dimension;
  time_msec_t t_build_start, t_build_end, t_ser_start, t_ser_end;
  if (n <= 0)
    return;
  vvec_hnsw_init (&H, dim, meta->vm_hnsw_m, meta->vm_ef_construction,
      vvec_hm_metric (meta->vm_metric), n, allvec);
  for (i = 0; i < n; i++)
    vvec_hnsw_set (&H, i, allvec + (size_t) i * dim);
  t_build_start = get_msec_real_time ();
  vvec_hnsw_build (&H, nthreads);
  t_build_end = get_msec_real_time ();
  t_ser_start = get_msec_real_time ();
  vvec_bulk_serialize_packed (qi, meta, &H, allrow);
  t_ser_end = get_msec_real_time ();
  log_info ("Vector index build timing: graph_build=%ldms serialize=%ldms (n=%d, dim=%d, threads=%d)",
      (long) (t_build_end - t_build_start),
      (long) (t_ser_end - t_ser_start),
      n, dim, nthreads);
  vvec_hnsw_free (&H);
}


/* Estimate the fast bulk builder's heap consumption for n vectors of dim d
   with HNSW parameter m.  The builder holds:
     - the caller's arena:       n * d * sizeof(float) + n * sizeof(int64)
     - H.vecs: borrowed from the caller arena, no second vector copy
     - H.mags:                   n * sizeof(float)
     - H.level:                  n * sizeof(int)
     - H.rows (pointer array):   n * sizeof(void*)
     - H.locks (per-node mutex): n * sizeof(pthread_mutex_t)
     - adjacency lists:          ~n * (M0 * sizeof(int) + sizeof(vh_row_t))
       (level 0 dominates; higher levels are geometrically rare)
   The vector arena dominates; the rest is ~224 bytes/node of overhead. */
static int64
vvec_fast_rebuild_estimated_bytes (int64 n, int dim, int m)
{
  int64 per_node;
  if (n <= 0 || dim <= 0)
    return 0;
  per_node = (int64) dim * sizeof (float)        /* allvec, borrowed as H.vecs */
           + (int64) sizeof (int64)              /* allrow */
           + (int64) sizeof (float)              /* H.mags */
           + (int64) sizeof (int)                /* H.level */
           + (int64) sizeof (void *)             /* H.rows ptr */
           + (int64) sizeof (pthread_mutex_t)    /* H.locks */
           + (int64) (2 * m) * sizeof (int)      /* level-0 adjacency (M0 = 2*m) */
           + (int64) sizeof (vh_row_t);          /* one vh_row_t for level 0 */
  return n * per_node;
}

/* An upper estimate of the transaction log a logged fast rebuild of n vectors
   writes.  vvec_bulk_serialize_packed () logs each packed page when it
   allocates it (its header: the rest is zeroes, which are not logged), then
   once more as a delta from its NEXT_DP to the end of its last record.
   Records are sized with a full level-0 list, which few nodes have, so this
   errs high.  An out-of-line vector adds its overflow pages, each logged
   once. */
static int64
vvec_fast_rebuild_log_bytes (int64 n, int dim, int m)
{
  int inline_dim = VVEC_DIM_FITS_INLINE (m, dim);
  int nb = vvec_node_layer_capacity (m, 0);
  int rec = vvec_cn_record_bytes (dim, 0, nb, !inline_dim);
  int64 per_page = VVEC_PK_DATA_USABLE / (rec > 0 ? rec : 1);
  int64 pages, page_log, est;
  if (n <= 0 || dim <= 0)
    return 0;
  if (per_page > VVEC_NREF_MAX_SLOTS)
    per_page = VVEC_NREF_MAX_SLOTS;
  if (per_page < 1)
    per_page = 1;
  pages = (n + per_page - 1) / per_page;
  page_log = VVEC_PK_DATA_BASE			/* the page as allocated */
      + VVEC_PK_DATA_BASE + (int64) rec * per_page	/* the one delta that fills it */
      + 2 * 32;					/* a LOG_VEC_PAGE record's own header, twice */
  est = pages * page_log;
  if (!inline_dim)
    {
      int cap = vvec_overflow_payload_capacity ();
      est += n * (((int64) dim * sizeof (float) + cap - 1) / cap) * PAGE_SZ;
    }
  return est;
}

/* A positive integer an operator set with registry_set (NAME, 'N'), or 0 when
   the key is unset, blank or not a positive number.  registry_get () asserts
   the transaction mutex (ASSERT_IN_TXN, regist.c). */
static int64
vvec_registry_positive (const char * name)
{
  caddr_t v;
  int64 n = 0;
  IN_TXN;
  v = registry_get (name);
  LEAVE_TXN;
  if (v && DV_STRINGP (v))
    n = (int64) strtoll ((char *) v, NULL, 10);
  dk_free_tree (v);
  return n > 0 ? n : 0;
}


/* The configured upper bound on fast-rebuild heap consumption: the registry key
   __vec_fast_rebuild_max_bytes, else the VVEC_FAST_REBUILD_MAX_BYTES environment
   variable, else the built-in default.  Read on every call, and the registry
   comes first, so an operator can change it on a running server --
   registry_set ('__vec_fast_rebuild_max_bytes', '20000000000') -- where the
   environment variable could only be set before the server started. */
static int64
vvec_fast_rebuild_max_bytes (void)
{
  int64 reg = vvec_registry_positive ("__vec_fast_rebuild_max_bytes");
  char *env;
  if (reg > 0)
    return reg;
  env = getenv ("VVEC_FAST_REBUILD_MAX_BYTES");
  if (env)
    {
      int64 v = (int64) strtoll (env, NULL, 10);
      if (v > 0)
        return v;
    }
  return VVEC_FAST_REBUILD_MAX_BYTES_DEFAULT;
}

/* Default fast-build thread count when the caller/index/env give none: the online
   CPU count, capped, so a bulk rebuild uses the machine without oversubscribing. */
static int
vvec_default_build_threads (void)
{
  long n = 0;
#ifdef _SC_NPROCESSORS_ONLN
  n = sysconf (_SC_NPROCESSORS_ONLN);
#endif
  if (n < 1)
    n = 4;
  if (n > VVEC_REBUILD_MAX_AUTO_THREADS)
    n = VVEC_REBUILD_MAX_AUTO_THREADS;
  return (int) n;
}


/* TEST-ONLY fault injection for the chunked replay rebuild.
 *
 * Gated entirely by the VVEC_TEST_CRASH_AFTER_CHUNK environment variable, which is
 * never set in production; when unset this is a single getenv per chunk (i.e. once
 * per VVEC_REPLAY_CHUNK_SIZE inserts) and does nothing.  When set to N, after the
 * Nth chunk commits it forces a checkpoint -- making the *partial* graph durable on
 * disk -- and then exits uncleanly (call_exit, exactly like raw_exit), so the
 * rebuild's final vvec_epoch_sync never runs.
 *
 * That reproduces, deterministically, a crash in the middle of a rebuild: on the
 * next start the checkpointed partial graph has graph_epoch > data_epoch (the
 * catalog was never synced), which vvec_epoch_reconcile must condemn to a rebuild
 * rather than trust.  The safety of this rests on vvec_graph_reset bumping the
 * epoch the instant the graph is emptied; without that a checkpoint of the emptied
 * graph could match the stale catalog and be trusted.  Exercised by
 * binsrc/tests/suite/tvvec_chunked_replay_crash.sh. */
static int
vvec_test_crash_after_chunk (query_instance_t * qi, int committed_chunks)
{
  const char * crash_after = getenv ("VVEC_TEST_CRASH_AFTER_CHUNK");
  query_t * qr;
  caddr_t err = NULL;
  if (!crash_after || committed_chunks != atoi (crash_after))
    return 0;
  /* Make the partial graph durable, then die without the final epoch sync. */
  qr = vvec_compile_text (qi->qi_client, &err, "checkpoint");
  if (!err && qr)
    {
      qr_quick_exec (qr, qi->qi_client, "", NULL, 0);
      qr_free (qr);
    }
  log_error ("Vector index: TEST fault injection VVEC_TEST_CRASH_AFTER_CHUNK=%s -- "
      "partial graph checkpointed after %d chunk(s), exiting uncleanly.",
      crash_after, committed_chunks);
  call_exit (0);
  return 1;   /* not reached */
}


/* Past the after-image limit lt_commit blows the transaction off (LTE_LOG_IMAGE
   -> SR108), losing the chunk; bytes per node vary with dim/hnsw_m/packing, so a
   row count cannot bound this. A quarter is left for the tripping row's images. */
static int
vvec_replay_chunk_log_full (query_instance_t * qi)
{
  lock_trx_t * lt = qi->qi_trx;
  if (!txn_after_image_limit || !lt || !lt->lt_log)
    return 0;
  return lt->lt_log->dks_bytes_sent > (OFF_T) (txn_after_image_limit - (txn_after_image_limit / 4));
}


/* Replay rebuild, chunked.  Whole-graph replay used to run in one transaction;
   every DPF_VEC page it dirtied stayed pinned -- uncheckpointable and
   unreplaceable -- until commit, so the resident dirty set grew with N and, once
   it outran the buffer pool, thrashed super-linearly (100K: 36s; 500K:
   impractical -- vvec-production-readiness/bench/500K_report.md).  Committing every
   VVEC_REPLAY_CHUNK_SIZE inserts bounds that set to one chunk -> linear.

   The graph is derived data (unlogged pages, epoch/health-driven recovery), so a
   rebuild need not be atomic: a crash mid-rebuild leaves graph_epoch ahead of
   data_epoch (synced only on completion) -> VEC80 -> rebuild; the partial graph is
   never trusted.  The caller holds the per-index writer lock across the commits;
   committing our own transaction releases locks and never awaits a row lock, and no
   vvec path holds a log/txn mutex while waiting on the writer mutex, so the mutex
   may be held across the commit without inverting lock order.

   Each chunk is read with a fresh, fully-consumed cursor keyed off the VE_D_ID
   BIGINT primary key, so no cursor is held across a commit and peak memory is one
   chunk -- replay never materializes all vectors the way fast does. */
static int64
vvec_replay_rebuild_chunked (query_instance_t * qi, vvec_meta_t * meta, int64 * skipped_ret)
{
  int dim = meta->vm_dimension;
  int64 rebuilt = 0, skipped = 0;
  int64 last_id = INT64_MIN;    /* VE_D_ID is BIGINT; no real id is <= this */
  int committed_chunks = 0;
  caddr_t err = NULL;
  char text[1024];
  query_t * qr;
  snprintf (text, sizeof (text),
      "select VE_D_ID, VE_EMBEDDING from %s where VE_D_ID > ? order by VE_D_ID",
      meta->vm_hidden_table);
  qr = vvec_compile_text (qi->qi_client, &err, text);
  if (err)
    sqlr_resignal (err);
  for (;;)
    {
      local_cursor_t * lc = NULL;
      int64 in_chunk = 0;
      err = qr_quick_exec (qr, qi->qi_client, "", &lc, 1,
	  ":0", (caddr_t) (ptrlong) last_id, QRP_INT);
      if (SQL_SUCCESS != err)
	{
	  qr_free (qr);
	  sqlr_resignal (err);
	}
      while (in_chunk < VVEC_REPLAY_CHUNK_SIZE && lc_next (lc))
	{
	  caddr_t row_id = lc_nth_col (lc, 0);
	  caddr_t embedding = lc_nth_col (lc, 1);
	  float * vec = NULL;
	  int vdim = 0;
	  int64 rid;
	  /* VE_D_ID is the BIGINT PK and the ORDER BY key: conversion cannot fail,
	     and advancing last_id off it guarantees forward progress. */
	  if (!vvec_row_id_to_i64 (row_id, &rid))
	    { skipped++; continue; }
	  last_id = rid;
	  in_chunk++;
	  if (!vvec_extract_floats (embedding, &vec, &vdim))
	    { skipped++; continue; }
	  vvec_apply_reduction (meta, &vec, &vdim);
	  if (vdim != dim)
	    {
	      dk_free ((caddr_t) vec, vdim * sizeof (float));
	      skipped++;
	      continue;
	    }
	  vvec_insert_graph (qi, meta, row_id, vec, vvec_vector_magnitude (vec, dim));
	  dk_free ((caddr_t) vec, vdim * sizeof (float));
	  rebuilt++;
	  /* After a row, so in_chunk is never 0 -- that is the loop's "done" signal. */
	  if (vvec_replay_chunk_log_full (qi))
	    break;
	}
      lc_free (lc);
      if (0 == in_chunk)
	break;                    /* cursor returned no rows -> done */
      /* Flush + release this chunk's dirty DPF_VEC buffers.  Raises on failure,
	 unwinding to the caller's QR_RESET_CODE (which releases the writer lock). */
      ddl_commit_trx (qi);
      vvec_keep_log_mode (qi);
      committed_chunks++;
      vvec_test_crash_after_chunk (qi, committed_chunks);   /* no-op unless env set */
    }
  qr_free (qr);
  *skipped_ret = skipped;
  return rebuilt;
}


/* Rebuild the HNSW graph from the transactional embeddings.
   <index>_vec_embeddings is the source of truth; the graph is derived from it.
   Replaying stored vectors is far cheaper than re-running the embedding model
   over the base table, which is what the create-time backfill does.

   method_override / threads_override carry an explicit __VEC_INDEX_REBUILD argument
   (VVEC_REBUILD_UNSET / 0 when the caller passed none).  */
static caddr_t
vvec_rebuild_impl (query_instance_t * qi, const char *func_name, char * index_name,
    int method_override, int threads_override)
{
  vvec_meta_t meta;
  local_cursor_t * lc = NULL;
  query_t * qr = NULL;
  int64 rebuilt = 0;
  int64 skipped = 0;
  dk_mutex_t * wmtx;
  rwlock_t * graph_gate;
  int dim, cap = 4096, n = 0;
  time_msec_t t_phase;
  /* Resolve which rebuild implementation to run.  Precedence, highest first:
   *   1. an explicit method passed to __VEC_INDEX_REBUILD (method_override);
   *   2. the index's stored default -- WITH (rebuild = ...) -> meta.vm_rebuild;
   *   3. the VVEC_FAST_REBUILD environment variable (transitional global fallback,
   *      whose numeric value also seeds the thread count);
   *   The fast builder's thread count follows its own precedence: the explicit
   *   argument, then the __vec_rebuild_threads registry key, then
   *   VVEC_FAST_REBUILD, then vvec_default_build_threads ().  The registry key
   *   sets threads alone -- unlike VVEC_FAST_REBUILD it neither forces the
   *   method nor skips the memory guard, and it can be changed while the
   *   server runs.
   *   4. the built-in default: 'auto', which picks fast once the embedding count
   *      reaches VVEC_REBUILD_AUTO_MIN (with the memory guard as backstop), else
   *      replay.  An operator who wants a specific method on every rebuild can
   *      set WITH (rebuild = 'fast'|'replay') on the index.
   * Both implementations are durability-equivalent -- page-backed graph, survives a
   * clean restart (see binsrc/tests/suite/tvvec_rebuild_durable.sh) -- but the fast
   * bulk build (build in memory via vvec_hnsw.h, serialize to DPF_VEC pages) is much
   * faster and produces a higher-recall graph. */
  char * fastenv = getenv ("VVEC_FAST_REBUILD");
  int env_threads = fastenv ? atoi (fastenv) : 0;
  int method, fast, fast_threads = 0;
  float * allvec = NULL;
  int64 * allrow = NULL;
  vvec_require_key (qi, func_name, index_name, &meta);
  dim = meta.vm_dimension;
  method = VVEC_REBUILD_UNSET != method_override ? method_override
         : VVEC_REBUILD_UNSET != meta.vm_rebuild ? meta.vm_rebuild
         : fastenv ? VVEC_REBUILD_FAST
         : VVEC_REBUILD_AUTO;
  if (VVEC_REBUILD_AUTO == method)
    {
      int64 nrows = vvec_hidden_row_count (qi, &meta);
      method = (nrows >= VVEC_REBUILD_AUTO_MIN) ? VVEC_REBUILD_FAST : VVEC_REBUILD_REPLAY;
      /* Memory guard: if the fast builder's estimated heap footprint exceeds
         the configured cap, fall back to replay rather than risk an OOM.
         'auto' is the implicit/default path, so protecting the server is the
         right call -- an operator who needs fast on a huge index can set
         rebuild='fast' explicitly or raise VVEC_FAST_REBUILD_MAX_BYTES. */
      if (VVEC_REBUILD_FAST == method)
        {
          int64 est = vvec_fast_rebuild_estimated_bytes (nrows, dim, meta.vm_hnsw_m);
          int64 cap_bytes = vvec_fast_rebuild_max_bytes ();
          if (est > cap_bytes)
            {
              log_error ("Vector index %s: auto-rebuild falling back to replay -- "
                "estimated fast-build heap %ld bytes exceeds cap %ld bytes "
                "(%ld vectors, dim %d). Set rebuild='fast' explicitly or raise "
                "VVEC_FAST_REBUILD_MAX_BYTES to override.",
                index_name, (long) est, (long) cap_bytes, (long) nrows, dim);
              method = VVEC_REBUILD_REPLAY;
            }
        }
      /* Log guard, for the same reason.  A logged fast build writes its whole
	 graph into this one transaction, which is marked blown off once its
	 log passes TransactionAfterImageLimit -- and that surfaces at commit,
	 after the build.  Replay commits whenever its log is three-quarters
	 full (vvec_replay_chunk_log_full).  The VEC95 check below does not
	 catch this: it is a lower bound, so as not to refuse an explicit
	 'fast' that would have fitted, and it put 4.6 MB on 12,000 nodes of
	 64 dimensions that logged 21.6 MB.  'auto' can afford the upper
	 estimate, since replay builds the same graph. */
      if (VVEC_REBUILD_FAST == method && REPL_NO_LOG != qi->qi_trx->lt_replicate && txn_after_image_limit > 0)
        {
          int64 log_est = vvec_fast_rebuild_log_bytes (nrows, dim, meta.vm_hnsw_m);
          int64 used = qi->qi_trx->lt_log ? (int64) qi->qi_trx->lt_log->dks_bytes_sent : 0;
          int64 room = (int64) txn_after_image_limit - used;
          if (log_est > room)
            {
              log_error ("Vector index %s: auto-rebuild falling back to replay -- a logged fast build "
                "of %ld vectors (dim %d) would write about %ld bytes of transaction log, more than the "
                "%ld bytes left under TransactionAfterImageLimit; replay commits as it goes.  Rebuild "
                "after log_enable (2) and checkpoint afterwards to use the fast builder.",
                index_name, (long) nrows, dim, (long) log_est, (long) (room > 0 ? room : 0));
              method = VVEC_REBUILD_REPLAY;
            }
        }
    }
  fast = (VVEC_REBUILD_FAST == method);
  if (fast)
    {
      int64 est;
      int64 cap_bytes;
      int64 nrows_for_est;
      /* For an explicit 'fast' call, warn if the estimate exceeds the cap but
         proceed -- the caller made a deliberate choice. For 'auto' we already
         fell back above, so this only fires for explicit fast. */
      nrows_for_est = vvec_hidden_row_count (qi, &meta);
      /* The row count is already required for the memory guard. Use it to
         allocate the load arena once instead of doubling from 4096 through a
         series of reallocations whose transient old+new footprint can be
         disastrous at multi-million-row scale. Keep the growth fallback for
         a concurrent/count discrepancy and for counts beyond the int builder
         limit. */
      if (nrows_for_est > cap && nrows_for_est <= 0x7fffffff)
        cap = (int) nrows_for_est;
      est = vvec_fast_rebuild_estimated_bytes (nrows_for_est, dim, meta.vm_hnsw_m);
      cap_bytes = vvec_fast_rebuild_max_bytes ();
      if (est > cap_bytes)
        log_error ("Vector index %s: WARNING -- explicit fast rebuild estimated "
          "heap %ld bytes exceeds recommended cap %ld bytes (%ld vectors, dim %d). "
          "Proceeding as requested; monitor for OOM.",
          index_name, (long) est, (long) cap_bytes, (long) nrows_for_est, dim);
      {
	int64 reg_threads = vvec_registry_positive ("__vec_rebuild_threads");
	if (reg_threads > VVEC_REBUILD_MAX_THREADS)
	  reg_threads = VVEC_REBUILD_MAX_THREADS;
	fast_threads = threads_override > 0 ? threads_override
		     : reg_threads > 0 ? (int) reg_threads
		     : env_threads > 0 ? env_threads
		     : vvec_default_build_threads ();
      }
      if (fast_threads < 1)
	fast_threads = 1;
      /* A logged fast rebuild writes every page of the new graph into this
	 transaction's log, and TransactionAfterImageLimit only marks the
	 transaction blown off as the log grows past it (TXN_CHECK_LOG_IMAGE,
	 log.c): the failure arrives at commit, after the whole in-memory build
	 and the serialize, with the old graph already reset.  One such build was
	 two hours lost.  So refuse up front when even a lower bound on that log
	 cannot fit -- every node's vector and level-0 neighbour list reach a
	 page at least once.  A lower bound, so a rebuild that would have fitted
	 is never refused; and it is checked before vvec_graph_reset (), so the
	 old graph keeps answering. */
      if (REPL_NO_LOG != qi->qi_trx->lt_replicate && txn_after_image_limit > 0)
	{
	  int64 floor_bytes = nrows_for_est
	      * ((int64) dim * sizeof (float) + (int64) 2 * meta.vm_hnsw_m * sizeof (int32));
	  int64 used = qi->qi_trx->lt_log ? (int64) qi->qi_trx->lt_log->dks_bytes_sent : 0;
	  int64 room = (int64) txn_after_image_limit - used;
	  if (floor_bytes > room)
	    sqlr_new_error ("42000", "VEC95",
		"Vector index %s: a logged fast rebuild of %ld vectors writes at least %ld bytes of "
		"transaction log, more than the %ld bytes left under TransactionAfterImageLimit, so it "
		"would fail at commit after building the whole graph.  Run it after log_enable (2) and "
		"checkpoint afterwards, or raise TransactionAfterImageLimit.",
		index_name, (long) nrows_for_est, (long) floor_bytes, (long) (room > 0 ? room : 0));
	}
      allvec = (float *) malloc ((size_t) cap * dim * sizeof (float));
      allrow = (int64 *) malloc ((size_t) cap * sizeof (int64));
      if (!allvec || !allrow)
        {
          free (allvec);
          free (allrow);
          sqlr_new_error ("HY001", "VEC94",
              "Vector index %s: cannot allocate fast-rebuild input arena for %d vectors of dimension %d.",
              index_name, cap, dim);
        }
    }
  /* A rebuild resets the graph to empty and refills it.  Exclude graph readers
     before taking the writer mutex: a page latch protects only the page a search
     currently holds, not an nref it will follow next, so freeing behind a search
     produces a reference to a free remap.  This order is load-bearing -- a graph
     reader may also enter an ordinary writer operation, so writer mutex -> graph
     write lock would permit an AB/BA deadlock. */
  graph_gate = vvec_graph_write_lock (meta.vm_it);
  wmtx = vvec_writer_lock (meta.vm_it);
  QR_RESET_CTX_T (qi->qi_thread)
    {
      /* Reset and load are the two phases with no timing of their own, and on a
         multi-million-node index they dominate: one measured rebuild spent 2.2 h
         in the graph build and serialize, and ~23 h before them.  Report both,
         so the next one does not need a debugger to say where it is. */
      t_phase = get_msec_real_time ();
      vvec_graph_reset (qi, &meta);
      log_info ("Vector index %s: graph reset in %ld ms", index_name,
          (long) (get_msec_real_time () - t_phase));
      if (fast)
	{
	  /* Flush + release the DPF_VEC pages vvec_graph_reset just freed BEFORE
	     the bulk build allocates fresh pages.  Without this, reset (walking +
	     dirtying every old page to free it) and the build (allocating the new
	     pages) pin ~2x the graph's page set in a single transaction; once that
	     resident dirty set outruns the buffer pool it deadlocks -- the buffer
	     allocator waits for a free buffer while every buffer is pinned by this
	     same uncommitted transaction (seen as a checkpoint/bp_flush hang under
	     e.g. NumberOfBuffers=2000 rebuilding a 10001-node graph).  The replay
	     path already bounds its dirty set via chunked commits; the fast path
	     needs this one commit so a re-fast-rebuild starts from the empty,
	     committed graph (which builds within the pool).  Safe: the graph is
	     derived data with epoch-based recovery (a crash here just yields
	     graph_epoch != data_epoch -> VEC80 -> rebuild), and the writer lock is
	     a dk_mutex held across the commit exactly as in the replay path. */
	  ddl_commit_trx (qi);
	  vvec_keep_log_mode (qi);
	  t_phase = get_msec_real_time ();
	  vvec_hidden_foreach (qi, meta.vm_hidden_table, &lc, &qr);
	  while (lc_next (lc))
	    {
	      caddr_t row_id = lc_nth_col (lc, 0);
	      caddr_t embedding = lc_nth_col (lc, 1);
	      float * vec = NULL;
	      int vdim = 0;
	      int64 rid;
	      if (!vvec_extract_floats (embedding, &vec, &vdim))
		{
		  skipped++;
		  continue;
		}
	      vvec_apply_reduction (&meta, &vec, &vdim);
	      if (vdim != dim || !vvec_row_id_to_i64 (row_id, &rid))
		{
		  dk_free ((caddr_t) vec, vdim * sizeof (float));
		  skipped++;
		  continue;
		}
	      if (n >= cap)
		{
		  int new_cap = cap <= 0x3fffffff ? cap * 2 : 0x7fffffff;
		  float *new_allvec;
		  int64 *new_allrow;
		  if (new_cap <= cap)
		    sqlr_new_error ("HY001", "VEC94",
		        "Vector index %s exceeds the fast builder's %d-row limit.", index_name, cap);
		  new_allvec = (float *) realloc (allvec, (size_t) new_cap * dim * sizeof (float));
		  if (!new_allvec)
		    sqlr_new_error ("HY001", "VEC94",
		        "Vector index %s: cannot grow fast-rebuild vector arena to %d rows.", index_name, new_cap);
		  allvec = new_allvec;
		  new_allrow = (int64 *) realloc (allrow, (size_t) new_cap * sizeof (int64));
		  if (!new_allrow)
		    sqlr_new_error ("HY001", "VEC94",
		        "Vector index %s: cannot grow fast-rebuild row-id arena to %d rows.", index_name, new_cap);
		  allrow = new_allrow;
		  cap = new_cap;
		}
	      memcpy (allvec + (size_t) n * dim, vec, (size_t) dim * sizeof (float));
	      allrow[n] = rid;
	      n++;
	      dk_free ((caddr_t) vec, vdim * sizeof (float));
	    }
	  log_info ("Vector index %s: loaded %d embedding(s) into the build arena in %ld ms (%ld skipped)",
	      index_name, n, (long) (get_msec_real_time () - t_phase), (long) skipped);
	  vvec_bulk_build_serialize (qi, &meta, allvec, allrow, n, fast_threads);
	  rebuilt = n;
	}
      else
	{
	  /* Replay is chunked: it commits every VVEC_REPLAY_CHUNK_SIZE inserts to
	     bound the resident dirty-buffer set.  It manages its own per-chunk
	     cursor (lc/qr stay NULL here). */
	  rebuilt = vvec_replay_rebuild_chunked (qi, &meta, &skipped);
	}
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_writer_unlock (wmtx);
      vvec_graph_unlock (graph_gate);
      if (lc)
	lc_free (lc);
      if (qr)
	qr_free (qr);
      free (allvec);
      free (allrow);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_writer_unlock (wmtx);
  vvec_graph_unlock (graph_gate);
  if (lc)
    lc_free (lc);
  if (qr)
    qr_free (qr);
  free (allvec);
  free (allrow);
  vvec_epoch_sync (qi, &meta);
  vvec_health_set (meta.vm_key->key_id, VVEC_HEALTH_OK);
  /* Rebuilds are infrequent, operationally significant events; record which
     implementation ran, with what parallelism, and how many rows it covered. */
  if (fast)
    log_error ("Vector index %s rebuilt: %ld embedding(s) via fast bulk build, %d thread(s); %ld row(s) skipped as unusable.",
	index_name, (long) rebuilt, fast_threads, (long) skipped);
  else
    log_error ("Vector index %s rebuilt: %ld embedding(s) via incremental replay; %ld row(s) skipped as unusable.",
	index_name, (long) rebuilt, (long) skipped);
  return box_num (rebuilt);
}


/* Retire a graph node whose embedding row is gone.
 *
 * An orphan means the graph insert reached the buffer pool but the owning
 * transaction did not commit -- the rollback case.  Reaping from reconciliation,
 * rather than from lt_rollback_hook or an ordinary search, is deliberate:
 *
 *   - it runs in ordinary query context with a valid qi, so taking page
 *     latches is safe.  The rollback path runs inside the transaction layer,
 *     where doing buffer I/O risks lock-order inversion;
 *   - a search's snapshot can legitimately miss a concurrent insert's
 *     uncommitted hidden row, so absence there does not prove an orphan;
 *   - it covers orphans from *any* cause, not only rollback;
 *   - it needs no new field on lock_trx_t, and no chaining of the
 *     single-slot lt_rollback_hook that rdf_core.c already owns.
 *
 * The epoch is decremented rather than advanced: the uncommitted insert
 * bumped it, so undoing that insert undoes the bump.  The epoch pair
 * re-converges and the index is not flagged for a rebuild it no longer needs.
 */
static void
vvec_reap_orphan_node (query_instance_t * qi, vvec_meta_t * meta, vvec_node_ref_t nref, caddr_t row_id)
{
  dk_mutex_t * wmtx;
  (void) row_id;
  wmtx = vvec_writer_lock (meta->vm_it);
  QR_RESET_CTX_T (qi->qi_thread)
    {
      dk_free_tree (vvec_mark_node_deleted_1 (qi, meta, nref, -1));
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_writer_unlock (wmtx);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_writer_unlock (wmtx);
  log_error ("Vector index %s: retired orphan graph node %ld -- it had no committed embedding row. "
      "This is the residue of a rolled-back transaction; the index remains usable.",
      meta->vm_key && meta->vm_key->key_name ? meta->vm_key->key_name : "<unknown>",
      (long) nref);
}


static caddr_t
vvec_delete_row_impl_1 (query_instance_t * qi, const char *func_name, char * index_name, caddr_t row_id, int sync_epoch, vvec_hidden_stmts_t * st)
{
  vvec_meta_t meta;
  dp_addr_t old_dp = 0;
  caddr_t changed = NULL;
  dk_mutex_t * wmtx;
  vvec_require_key (qi, func_name, index_name, &meta);
  /* Serialize only the graph mutation (a soft-delete flips a node flag and
     read-modify-writes the root counters); the transactional hidden-table
     delete and epoch sync stay outside the lock, as in the insert path, so no
     row lock is ever awaited while the writer mutex is held.  The lookup is
     inside: undoing a rolled-back delete can bring the row's node back.  */
  wmtx = vvec_writer_lock (meta.vm_it);
  QR_RESET_CTX_T (qi->qi_thread)
    {
      vvec_undo_apply (qi, &meta);
      if (vvec_hidden_lookup_existing (qi, &meta, row_id, &old_dp))
	vvec_delete_node_noted (qi, &meta, old_dp, &changed);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_writer_unlock (wmtx);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_writer_unlock (wmtx);
  if (!old_dp)
    return box_num (0);
  vvec_hidden_delete (qi, &meta, row_id, st);
  if (sync_epoch)
    vvec_write_epoch_sync (qi, &meta);
  return changed;
}


static caddr_t
vvec_insert_embedding_impl_1 (query_instance_t * qi, const char *func_name, char * index_name, caddr_t row_id, caddr_t embedding,
    const char *source_hash, int sync_epoch, vvec_hidden_stmts_t * st)
{
  vvec_meta_t meta;
  float * vec = NULL;
  int dim = 0;
  float magnitude;
  dp_addr_t old_dp = 0;
  dp_addr_t new_dp = 0;
  dk_mutex_t * wmtx;
  caddr_t stored;
  vvec_require_key (qi, func_name, index_name, &meta);
  if (!vvec_extract_floats (embedding, &vec, &dim))
    sqlr_new_error ("22023", "VEC30", "Malformed embedding vector for %s.", index_name);
  /* Boxed before reduction, so the hidden table keeps the native embedding and a
     reduced index stays rebuildable at another target dimension. */
  stored = vvec_float_box (vec, dim);
  vvec_apply_reduction (&meta, &vec, &dim);
  if (dim != meta.vm_dimension)
    {
      dk_free_box (stored);
      dk_free ((caddr_t) vec, dim * sizeof (float));
      sqlr_new_error ("22023", "VEC31", "Embedding dimension %d does not match vector index dimension %d.", dim, meta.vm_dimension);
    }
  magnitude = vvec_vector_magnitude (vec, dim);
  /* The hidden-table read is a plain (non-locking) select and stays outside the
     writer lock.  */
  vvec_hidden_lookup_existing (qi, &meta, row_id, &old_dp);
  /* Serialize the graph mutation -- and ONLY the graph mutation -- per index.
     The transactional writes (hidden_upsert, epoch_sync) are kept OUTSIDE the
     lock: each takes a row lock that its worker holds until commit, so awaiting
     one while holding the writer mutex would invert lock order against another
     writer that holds the row and is waiting for the mutex (a real deadlock, not
     hypothetical -- concurrent multi-row inserts share the per-index
     VEC_INDEX_EPOCH row).  Serializing just insert_graph/mark_node_deleted is
     what actually prevents graph corruption; the hidden table and the epoch
     catalog are transactional and safe on their own.  */
  wmtx = vvec_writer_lock (meta.vm_it);
  QR_RESET_CTX_T (qi->qi_thread)
    {
      if (vvec_undo_apply (qi, &meta))
	{
	  old_dp = 0;
	  vvec_hidden_lookup_existing (qi, &meta, row_id, &old_dp);
	}
      if (old_dp)
	vvec_delete_node_noted (qi, &meta, old_dp, NULL);
      new_dp = vvec_insert_graph (qi, &meta, row_id, vec, magnitude);
      vvec_undo_note (qi, &meta, VVEC_UNDO_INSERT, new_dp);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_writer_unlock (wmtx);
      dk_free ((caddr_t) vec, dim * sizeof (float));
      dk_free_box (stored);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_writer_unlock (wmtx);
  vvec_hidden_upsert (qi, &meta, row_id, stored, source_hash, magnitude, st);
  if (sync_epoch)
    vvec_write_epoch_sync (qi, &meta);
  dk_free ((caddr_t) vec, dim * sizeof (float));
  dk_free_box (stored);
  return box_num (new_dp);
}


/* Store an embedding WITHOUT linking it into the graph.
 *
 * <index>_vec_embeddings is the source of truth and the graph is derived from
 * it (see vvec_rebuild_impl), so a bulk build can be split in two: stage every
 * embedding here, then derive the whole graph once.  That is worth doing
 * because incremental linking gets slower as the graph grows -- each insert
 * searches more neighbours -- while a bulk build is a single parallel pass.
 * Measured on 57,600 FiQA documents: ~50 minutes of incremental linking that a
 * 6-second bulk rebuild then discarded and replaced with a graph 4x smaller.
 *
 * There is deliberately no graph bookkeeping here, not even marking a row's
 * existing node deleted: the bulk build replaces the graph wholesale from the
 * hidden table, so any node left behind is discarded rather than orphaned.
 * The corollary is that an index is NOT searchable between staging and the
 * rebuild -- callers must keep it out of the searchable state for the whole
 * window, which the SPARQL layer does by holding SVI_STATE = 'refreshing'
 * (search signals VEC50 unless the state is 'active').
 */
static caddr_t
vvec_stage_embedding_impl_1 (query_instance_t * qi, const char *func_name, char * index_name,
    caddr_t row_id, caddr_t embedding, const char *source_hash, vvec_hidden_stmts_t * st)
{
  vvec_meta_t meta;
  float * vec = NULL;
  int dim = 0;
  float magnitude;
  caddr_t stored;
  vvec_require_key (qi, func_name, index_name, &meta);
  if (!vvec_extract_floats (embedding, &vec, &dim))
    sqlr_new_error ("22023", "VEC30", "Malformed embedding vector for %s.", index_name);
  stored = vvec_float_box (vec, dim);
  vvec_apply_reduction (&meta, &vec, &dim);
  if (dim != meta.vm_dimension)
    {
      dk_free_box (stored);
      dk_free ((caddr_t) vec, dim * sizeof (float));
      sqlr_new_error ("22023", "VEC31", "Embedding dimension %d does not match vector index dimension %d.", dim, meta.vm_dimension);
    }
  magnitude = vvec_vector_magnitude (vec, dim);
  /* No writer lock: this touches only the transactional hidden table, and the
     graph -- the thing the writer lock protects -- is not read or written. */
  vvec_hidden_upsert (qi, &meta, row_id, stored, source_hash, magnitude, st);
  dk_free ((caddr_t) vec, dim * sizeof (float));
  dk_free_box (stored);
  return box_num (1);
}


/* Single-row entry points sync the catalog epoch immediately.  The batch
   entry points below pass sync_epoch = 0 and sync once at the end instead:
   the catalog only has to agree with whatever the root page ends up at, so
   one write per batch is both correct and far cheaper than one per row.  */
static caddr_t
vvec_delete_row_impl (query_instance_t * qi, const char *func_name, char * index_name, caddr_t row_id)
{
  return vvec_delete_row_impl_1 (qi, func_name, index_name, row_id, 1, NULL);
}


static caddr_t
vvec_insert_embedding_impl (query_instance_t * qi, const char *func_name, char * index_name, caddr_t row_id, caddr_t embedding)
{
  return vvec_insert_embedding_impl_1 (qi, func_name, index_name, row_id, embedding, NULL, 1, NULL);
}


static caddr_t
vvec_insert_test_embedding_impl (query_instance_t * qi, const char *func_name, char * index_name, caddr_t row_id, int pos1, int pos2)
{
  vvec_meta_t meta;
  caddr_t embedding;
  caddr_t ret;
  vvec_require_key (qi, func_name, index_name, &meta);
  embedding = vvec_make_test_vector_box (meta.vm_dimension, pos1, pos2);
  ret = vvec_insert_embedding_impl (qi, func_name, index_name, row_id, embedding);
  dk_free_tree (embedding);
  return ret;
}


static int
vvec_next_int_in_text (const char **scan, int *ret)
{
  const char *p = *scan;
  char *end = NULL;
  long val;
  while (p && *p)
    {
      if ((*p >= '0' && *p <= '9') || ('-' == *p && p[1] >= '0' && p[1] <= '9'))
	break;
      p++;
    }
  if (!p || !*p)
    return 0;
  val = strtol (p, &end, 10);
  if (!end || end == p)
    return 0;
  *scan = end;
  *ret = (int) val;
  return 1;
}


static caddr_t
vvec_make_test_vector_from_text (int dim, const char *text)
{
  const char *scan = text;
  int pos1 = -1;
  int pos2 = -1;
  if (!vvec_next_int_in_text (&scan, &pos1))
    {
      unsigned int hash = 2166136261U;
      const unsigned char *p;
      for (p = (const unsigned char *) text; p && *p; p++)
	hash = (hash ^ *p) * 16777619U;
      pos1 = dim ? ((int) (hash % (unsigned int) dim)) : -1;
    }
  else
    {
      if (dim && pos1 >= dim)
	pos1 %= dim;
      if (pos1 < 0)
	pos1 = -1;
      if (vvec_next_int_in_text (&scan, &pos2))
	{
	  if (dim && pos2 >= dim)
	    pos2 %= dim;
	  if (pos2 < 0)
	    pos2 = -1;
	}
    }
  return vvec_make_test_vector_box (dim, pos1, pos2);
}


static caddr_t
vvec_source_hash_box (const char *text)
{
  static const char hex[] = "0123456789abcdef";
  unsigned char digest[16];
  char out[33];
  MD5_CTX ctx;
  int inx;
  if (!text)
    text = "";
  MD5_Init (&ctx);
  MD5_Update (&ctx, (const unsigned char *) text, (unsigned long) strlen (text));
  MD5_Final (digest, &ctx);
  for (inx = 0; inx < 16; inx++)
    {
      out[inx * 2] = hex[(digest[inx] >> 4) & 0x0f];
      out[(inx * 2) + 1] = hex[digest[inx] & 0x0f];
    }
  out[32] = 0;
  return box_dv_short_string (out);
}


static caddr_t
vvec_embed_text_for_model (query_instance_t * qi, const char *func_name, char * index_name, vvec_meta_t * meta, char * text_value)
{
  (void) func_name;
  caddr_t err = NULL;
  local_cursor_t * lc = NULL;
  query_t * qr;
  char model_name[256];
  char model_type[128];
  int model_uses_http_provider = 0;
  long handle = 0;
  caddr_t embedding = NULL;
  caddr_t flat;
  caddr_t utf8_text = NULL;
  model_name[0] = 0;
  model_type[0] = 0;
  qr = sql_compile_static ("select model_name, model_type, handle from DB.DBA.ONNX_MODELS where model_id = ?", qi->qi_client, &err, SQLC_DEFAULT);
  if (err)
    sqlr_resignal (err);
  err = qr_quick_exec (qr, qi->qi_client, "", &lc, 1, ":0", (caddr_t) (ptrlong) meta->vm_model_id, QRP_INT);
  if (SQL_SUCCESS != err)
    {
      qr_free (qr);
      sqlr_resignal (err);
    }
  if (!lc || !lc_next (lc))
    {
      if (lc)
	lc_free (lc);
      qr_free (qr);
      sqlr_new_error ("42S02", "VEC50", "Vector index %s references missing ONNX model id %d.", index_name, meta->vm_model_id);
    }
  if (vvec_is_string_box (lc_nth_col (lc, 0)))
    snprintf (model_name, sizeof (model_name), "%s", (char *) lc_nth_col (lc, 0));
  if (vvec_is_string_box (lc_nth_col (lc, 1)))
    snprintf (model_type, sizeof (model_type), "%s", (char *) lc_nth_col (lc, 1));
  if (lc_nth_col (lc, 2) && DV_DB_NULL != DV_TYPE_OF (lc_nth_col (lc, 2)))
    handle = (long) unbox (lc_nth_col (lc, 2));
  lc_free (lc);
  qr_free (qr);
  lc = NULL;

  /* a non-ASCII SPARQL literal arrives as a wide string; the models take UTF-8 */
  if (DV_WIDESTRINGP (text_value))
    text_value = utf8_text = box_wide_as_utf8_char (text_value, box_length (text_value) / sizeof (wchar_t) - 1, DV_STRING);

  if (!stricmp (model_type, "test_embedding") || !stricmp (model_type, "vvec_test_embedding"))
    {
      flat = vvec_make_test_vector_from_text (meta->vm_dimension, text_value);
      dk_free_box (utf8_text);
      return flat;
    }

  model_uses_http_provider =
      !stricmp (model_type, "openai") || !stricmp (model_type, "openai_embedding") ||
      !stricmp (model_type, "ollama") || !stricmp (model_type, "ollama_embedding") ||
      !stricmp (model_type, "lmstudio") || !stricmp (model_type, "lm_studio") || !stricmp (model_type, "lmstudio_embedding") ||
      !stricmp (model_type, "openai_compatible");

  if (!model_uses_http_provider && !handle)
    {
      dk_free_box (utf8_text);
      sqlr_new_error ("42000", "VEC51", "Automatic embedding for vector index %s requires a loaded handle for model %s in DB.DBA.ONNX_MODELS.", index_name, model_name[0] ? model_name : "<unknown>");
    }

  qr = sql_compile_static (model_uses_http_provider ? "select DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL (?, ?)" : "select ONNX_EMBED_TEXT (?, ?)", qi->qi_client, &err, SQLC_DEFAULT);
  if (err)
    {
      dk_free_tree (err);
      dk_free_box (utf8_text);
      sqlr_new_error ("42000", "VEC52", "Automatic embedding for vector index %s requires the ONNX_EMBED_TEXT BIF from the ONNX plugin.", index_name);
    }
  err = qr_quick_exec (qr, qi->qi_client, "", &lc, 2,
      ":0", model_uses_http_provider ? (caddr_t) model_name : (caddr_t) (ptrlong) handle, model_uses_http_provider ? QRP_STR : QRP_INT,
      ":1", text_value, QRP_STR);
  dk_free_box (utf8_text);
  if (SQL_SUCCESS != err)
    {
      qr_free (qr);
      sqlr_resignal (err);
    }
  if (lc && lc_next (lc))
    embedding = box_copy_tree (lc_nth_col (lc, 0));
  if (lc)
    lc_free (lc);
  qr_free (qr);
  if (!embedding)
    sqlr_new_error ("42000", "VEC53", "ONNX_EMBED_TEXT returned no embedding for vector index %s.", index_name);
  /* Normalize here rather than at each consumer: this is the single point every
     generated embedding passes through, stored or returned to SQL as a query vector. */
  flat = vvec_to_float_box (embedding);
  dk_free_tree (embedding);
  if (!flat)
    sqlr_new_error ("22023", "VEC30", "Malformed embedding vector for %s.", index_name);
  return flat;
}


static caddr_t
bif_vvec_insert_embedding (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_INSERT_EMBEDDING");
  caddr_t row_id = bif_arg (qst, args, 1, "__VEC_INDEX_INSERT_EMBEDDING");
  caddr_t embedding = bif_arg (qst, args, 2, "__VEC_INDEX_INSERT_EMBEDDING");
  return vvec_insert_embedding_impl (qi, "__VEC_INDEX_INSERT_EMBEDDING", index_name, row_id, embedding);
}


static caddr_t
vvec_embed_and_insert_impl (query_instance_t * qi, const char *func_name, char * index_name, caddr_t row_id, char * text_value)
{
  vvec_meta_t meta;
  float * vec = NULL;
  int dim = 0;
  float magnitude;
  dp_addr_t old_dp = 0;
  dp_addr_t new_dp = 0;
  caddr_t source_hash;
  caddr_t old_hash = NULL;
  caddr_t embedding;
  dk_mutex_t * wmtx;
  vvec_require_key (qi, func_name, index_name, &meta);
  source_hash = vvec_source_hash_box (text_value);
  old_hash = vvec_hidden_source_hash (qi, &meta, row_id);
  if (old_hash && !strcmp ((char *) old_hash, (char *) source_hash))
    {
      dk_free_tree (old_hash);
      dk_free_tree (source_hash);
      return box_num (0);
    }
  if (old_hash)
    dk_free_tree (old_hash);
  embedding = vvec_embed_text_for_model (qi, func_name, index_name, &meta, text_value);
  if (!vvec_extract_floats (embedding, &vec, &dim))
    sqlr_new_error ("22023", "VEC30", "Malformed embedding vector for %s.", index_name);
  vvec_apply_reduction (&meta, &vec, &dim);
  if (dim != meta.vm_dimension)
    sqlr_new_error ("22023", "VEC31", "Embedding dimension %d does not match vector index dimension %d.", dim, meta.vm_dimension);
  magnitude = vvec_vector_magnitude (vec, dim);
  /* The embedding call above (a possibly slow remote/ONNX round trip) already
     ran outside the lock.  As in vvec_insert_embedding_impl_1, only the graph
     mutation is serialized; the transactional hidden_upsert and epoch_sync run
     after the mutex is released.  */
  vvec_hidden_lookup_existing (qi, &meta, row_id, &old_dp);
  wmtx = vvec_writer_lock (meta.vm_it);
  QR_RESET_CTX_T (qi->qi_thread)
    {
      if (vvec_undo_apply (qi, &meta))
	{
	  old_dp = 0;
	  vvec_hidden_lookup_existing (qi, &meta, row_id, &old_dp);
	}
      if (old_dp)
	vvec_delete_node_noted (qi, &meta, old_dp, NULL);
      new_dp = vvec_insert_graph (qi, &meta, row_id, vec, magnitude);
      vvec_undo_note (qi, &meta, VVEC_UNDO_INSERT, new_dp);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_writer_unlock (wmtx);
      dk_free ((caddr_t) vec, dim * sizeof (float));
      dk_free_tree (embedding);
      dk_free_tree (source_hash);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_writer_unlock (wmtx);
  vvec_hidden_upsert (qi, &meta, row_id, embedding, (char *) source_hash, magnitude, NULL);
  vvec_write_epoch_sync (qi, &meta);
  dk_free ((caddr_t) vec, dim * sizeof (float));
  dk_free_tree (embedding);
  dk_free_tree (source_hash);
  return box_num (new_dp);
}


static caddr_t
bif_vvec_embed_and_insert (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_EMBED_AND_INSERT");
  caddr_t row_id = bif_arg (qst, args, 1, "__VEC_INDEX_EMBED_AND_INSERT");
  char * text_value = bif_string_arg (qst, args, 2, "__VEC_INDEX_EMBED_AND_INSERT");
  return vvec_embed_and_insert_impl (qi, "__VEC_INDEX_EMBED_AND_INSERT", index_name, row_id, text_value);
}


static caddr_t
bif_vvec_query_text_vector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_QUERY_TEXT_VECTOR");
  char * text_value = bif_string_arg (qst, args, 1, "__VEC_INDEX_QUERY_TEXT_VECTOR");
  vvec_meta_t meta;
  caddr_t embedding;
  vvec_require_key (qi, "__VEC_INDEX_QUERY_TEXT_VECTOR", index_name, &meta);
  /* A precomputed-vector (source_kind='vector') index has no model by design, so
   * a text query cannot be embedded.  Fail with a clear, catchable error that
   * points at by-vector search instead of the generic missing-model path. */
  if (VVEC_SOURCE_VECTOR == meta.vm_source_kind)
    sqlr_new_error ("42000", "VEC88",
        "Vector index %.300s has no embedding model (source_kind='vector'); query it by vector with X_SIMILAR (col, <vector>, k), not by text.",
        index_name);
  if (vvec_query_text_vector_mtx)
    {
      mutex_enter (vvec_query_text_vector_mtx);
      if (vvec_query_text_vector_qi == qi
	  && vvec_query_text_vector_model_id == meta.vm_model_id
	  && vvec_query_text_vector_index
	  && vvec_query_text_vector_text
	  && vvec_query_text_vector_embedding
	  && 0 == strcmp ((char *) vvec_query_text_vector_index, index_name)
	  && 0 == strcmp ((char *) vvec_query_text_vector_text, text_value))
	{
	  embedding = box_copy_tree (vvec_query_text_vector_embedding);
	  mutex_leave (vvec_query_text_vector_mtx);
	  return embedding;
	}
      mutex_leave (vvec_query_text_vector_mtx);
    }
  embedding = vvec_embed_text_for_model (qi, "__VEC_INDEX_QUERY_TEXT_VECTOR", index_name, &meta, text_value);
  vvec_query_text_vector_calls++;
  if (vvec_query_text_vector_mtx)
    {
      mutex_enter (vvec_query_text_vector_mtx);
      dk_free_tree (vvec_query_text_vector_index);
      dk_free_tree (vvec_query_text_vector_text);
      dk_free_tree (vvec_query_text_vector_embedding);
      vvec_query_text_vector_qi = qi;
      vvec_query_text_vector_model_id = meta.vm_model_id;
      vvec_query_text_vector_index = box_dv_short_string (index_name);
      vvec_query_text_vector_text = box_dv_short_string (text_value);
      vvec_query_text_vector_embedding = box_copy_tree (embedding);
      mutex_leave (vvec_query_text_vector_mtx);
    }
  return embedding;
}


static caddr_t
bif_vvec_query_text_vector_calls (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long ret;
  (void) err_ret;
  ret = vvec_query_text_vector_calls;
  if (BOX_ELEMENTS (args) > 0 && bif_long_arg (qst, args, 0, "__VEC_INDEX_QUERY_TEXT_VECTOR_CALLS"))
    {
      vvec_query_text_vector_calls = 0;
      if (vvec_query_text_vector_mtx)
	{
	  mutex_enter (vvec_query_text_vector_mtx);
	  dk_free_tree (vvec_query_text_vector_index);
	  dk_free_tree (vvec_query_text_vector_text);
	  dk_free_tree (vvec_query_text_vector_embedding);
	  vvec_query_text_vector_qi = NULL;
	  vvec_query_text_vector_index = NULL;
	  vvec_query_text_vector_text = NULL;
	  vvec_query_text_vector_model_id = 0;
	  vvec_query_text_vector_embedding = NULL;
	  mutex_leave (vvec_query_text_vector_mtx);
	}
    }
  return box_num (ret);
}


static caddr_t
bif_vvec_delete_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_DELETE_ROW");
  caddr_t row_id = bif_arg (qst, args, 1, "__VEC_INDEX_DELETE_ROW");
  return vvec_delete_row_impl (qi, "__VEC_INDEX_DELETE_ROW", index_name, row_id);
}


static caddr_t
bif_vvec_delete_embedding (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_DELETE_EMBEDDING");
  caddr_t row_id = bif_arg (qst, args, 1, "__VEC_INDEX_DELETE_EMBEDDING");
  return vvec_delete_row_impl (qi, "__VEC_INDEX_DELETE_EMBEDDING", index_name, row_id);
}


static caddr_t
bif_vvec_delete_batch (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_DELETE_BATCH");
  caddr_t * row_ids = (caddr_t *) bif_array_arg (qst, args, 1, "__VEC_INDEX_DELETE_BATCH");
  vvec_hidden_stmts_t st;
  int inx;
  int deleted = 0;
  memset (&st, 0, sizeof (st));
  QR_RESET_CTX_T (qi->qi_thread)
    {
      for (inx = 0; inx < (int) BOX_ELEMENTS (row_ids); inx++)
	deleted += (int) unbox (vvec_delete_row_impl_1 (qi, "__VEC_INDEX_DELETE_BATCH", index_name, row_ids[inx], 0, &st));
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_hidden_stmts_free (&st);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_hidden_stmts_free (&st);
  vvec_epoch_sync_by_name (qi, "__VEC_INDEX_DELETE_BATCH", index_name);
  return box_num (deleted);
}


static caddr_t
bif_vvec_insert_test_embedding (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_INSERT_TEST_EMBEDDING");
  caddr_t row_id = bif_arg (qst, args, 1, "__VEC_INDEX_INSERT_TEST_EMBEDDING");
  int pos1 = bif_long_arg (qst, args, 2, "__VEC_INDEX_INSERT_TEST_EMBEDDING");
  int pos2 = bif_long_arg (qst, args, 3, "__VEC_INDEX_INSERT_TEST_EMBEDDING");
  return vvec_insert_test_embedding_impl (qi, "__VEC_INDEX_INSERT_TEST_EMBEDDING", index_name, row_id, pos1, pos2);
}


/* __VEC_INDEX_TEST_EMBEDDING (dim, text) -> the deterministic vector a
 * test_embedding model stands for.
 *
 * The generator lives here and nowhere else on purpose.  The SQL-side insert
 * path reaches it through vvec_embed_text_for_model, but the SPARQL-side
 * backfill embeds in PL (DB.DBA.VEC_INDEX_EMBED_TEXTS), which had no way to ask
 * for it and raised VEC33 instead -- so a test_embedding model that
 * VEC_INDEX_REFRESH's own guard admits could not actually be refreshed.
 * Exposing the generator rather than reimplementing it in PL is what keeps the
 * two paths producing byte-identical vectors; an independent implementation
 * that drifted would not fail, it would quietly return different neighbours
 * depending on which surface built the index. */
static caddr_t
bif_vvec_test_embedding (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  int dim = (int) bif_long_arg (qst, args, 0, "__VEC_INDEX_TEST_EMBEDDING");
  char * text = bif_string_arg (qst, args, 1, "__VEC_INDEX_TEST_EMBEDDING");
  if (dim <= 0 || dim > (0x7fffffff / (int) sizeof (float)))
    sqlr_new_error ("22023", "VEC15", "__VEC_INDEX_TEST_EMBEDDING needs a positive dimension, not %d.", dim);
  return vvec_make_test_vector_from_text (dim, text);
}


/* The optional fourth argument of the batch BIFs: the text each embedding was
   made from, or NULL.  Given, each hidden row keeps the text's SOURCE_HASH, as
   a row embedded by __VEC_INDEX_EMBED_AND_INSERT does, so a later update that
   leaves the text as it was is not embedded again. */
static caddr_t *
vvec_batch_texts_arg (caddr_t * qst, state_slot_t ** args, const char *func_name, int n_rows)
{
  caddr_t texts;
  if (BOX_ELEMENTS (args) < 4)
    return NULL;
  texts = bif_arg (qst, args, 3, func_name);
  if (DV_DB_NULL == DV_TYPE_OF (texts))
    return NULL;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (texts) || (int) BOX_ELEMENTS (texts) != n_rows)
    sqlr_new_error ("22023", "VEC32", "%s: texts must be an array with one text per row.", func_name);
  return (caddr_t *) texts;
}


static caddr_t
vvec_batch_text_hash (caddr_t * texts, int inx)
{
  if (!texts || !DV_STRINGP (texts[inx]))
    return NULL;
  return vvec_source_hash_box (texts[inx]);
}


static caddr_t
bif_vvec_insert_batch (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_INSERT_BATCH");
  caddr_t * row_ids = (caddr_t *) bif_array_arg (qst, args, 1, "__VEC_INDEX_INSERT_BATCH");
  caddr_t * embeddings = (caddr_t *) bif_array_arg (qst, args, 2, "__VEC_INDEX_INSERT_BATCH");
  caddr_t * texts;
  caddr_t hash = NULL;
  vvec_hidden_stmts_t st;
  int inx;
  if ((int) BOX_ELEMENTS (row_ids) != (int) BOX_ELEMENTS (embeddings))
    sqlr_new_error ("22023", "VEC32", "row_ids and embedding_vecs must have the same cardinality.");
  texts = vvec_batch_texts_arg (qst, args, "__VEC_INDEX_INSERT_BATCH", (int) BOX_ELEMENTS (row_ids));
  memset (&st, 0, sizeof (st));
  QR_RESET_CTX_T (qi->qi_thread)
    {
      for (inx = 0; inx < (int) BOX_ELEMENTS (row_ids); inx++)
	{
	  hash = vvec_batch_text_hash (texts, inx);
	  vvec_insert_embedding_impl_1 (qi, "__VEC_INDEX_INSERT_BATCH", index_name, row_ids[inx], embeddings[inx], hash, 0, &st);
	  dk_free_box (hash);
	  hash = NULL;
	}
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      dk_free_box (hash);
      vvec_hidden_stmts_free (&st);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_hidden_stmts_free (&st);
  vvec_epoch_sync_by_name (qi, "__VEC_INDEX_INSERT_BATCH", index_name);
  return box_num (BOX_ELEMENTS (row_ids));
}


/* Stage a batch of embeddings without touching the graph; see
   vvec_stage_embedding_impl_1.  No epoch sync -- the epoch tracks the graph
   root page, which this does not move; the rebuild that derives the graph
   syncs it. */
static caddr_t
bif_vvec_stage_batch (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_STAGE_BATCH");
  caddr_t * row_ids = (caddr_t *) bif_array_arg (qst, args, 1, "__VEC_INDEX_STAGE_BATCH");
  caddr_t * embeddings = (caddr_t *) bif_array_arg (qst, args, 2, "__VEC_INDEX_STAGE_BATCH");
  caddr_t * texts;
  caddr_t hash = NULL;
  vvec_hidden_stmts_t st;
  int inx;
  if ((int) BOX_ELEMENTS (row_ids) != (int) BOX_ELEMENTS (embeddings))
    sqlr_new_error ("22023", "VEC32", "row_ids and embedding_vecs must have the same cardinality.");
  texts = vvec_batch_texts_arg (qst, args, "__VEC_INDEX_STAGE_BATCH", (int) BOX_ELEMENTS (row_ids));
  memset (&st, 0, sizeof (st));
  QR_RESET_CTX_T (qi->qi_thread)
    {
      for (inx = 0; inx < (int) BOX_ELEMENTS (row_ids); inx++)
	{
	  hash = vvec_batch_text_hash (texts, inx);
	  vvec_stage_embedding_impl_1 (qi, "__VEC_INDEX_STAGE_BATCH", index_name, row_ids[inx], embeddings[inx], hash, &st);
	  dk_free_box (hash);
	  hash = NULL;
	}
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      dk_free_box (hash);
      vvec_hidden_stmts_free (&st);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_hidden_stmts_free (&st);
  return box_num (BOX_ELEMENTS (row_ids));
}


/* Shared vector-search execution helper.
 *
 * Validates the index and query vector, runs the HNSW graph search via
 * vvec_search_graph, and packs the hits into the public (row_id, distance)
 * result box.  Both the BIF-side helpers (__VEC_INDEX_SEARCH, __VEC_INDEX_SEARCH_TEST_EMBEDDING)
 * and the development-path BIF __vvec_ann_plan call this, so a future
 * vvec_search_node_t plan node can reuse the same kernel without duplicating
 * validation / metric-resolution logic.
 */
caddr_t
vvec_search_run (query_instance_t * qi, const char *func_name, char * index_name, caddr_t query_vec, int k, int ef_search)
{
  vvec_meta_t meta;
  float * vec = NULL;
  int dim = 0;
  float magnitude;
  vvec_search_metrics_t metrics;
  caddr_t ret;
  vvec_require_key (qi, func_name, index_name, &meta);
  vvec_require_healthy (qi, &meta, func_name);
  if (!vvec_extract_floats (query_vec, &vec, &dim))
    sqlr_new_error ("22023", "VEC33", "Malformed query vector for %s.", index_name);
  vvec_apply_reduction (&meta, &vec, &dim);
  if (dim != meta.vm_dimension)
    sqlr_new_error ("22023", "VEC34", "Query dimension %d does not match vector index dimension %d.", dim, meta.vm_dimension);
  if (k <= 0)
    k = 10;
  if (ef_search < k)
    ef_search = k;
  memset (&metrics, 0, sizeof (metrics));
  magnitude = vvec_vector_magnitude (vec, dim);
  ret = vvec_search_graph_and_pack (qi, &meta, vec, magnitude, k, ef_search, &metrics);
  dk_free ((caddr_t) vec, dim * sizeof (float));
  return ret;
}


/* Phase 5 fast-lane: search with a pre-resolved key, skipping the name→key
 * schema scan and the option re-parse in vvec_require_key.  Used by the
 * vvec_search_node plan node which already holds the dbe_key_t* from
 * compilation.  The BIF path (bif_vvec_search) still uses vvec_search_run
 * because it receives only the index name string. */
caddr_t
vvec_search_run_key (query_instance_t * qi, const char *func_name, dbe_key_t * key, caddr_t query_vec, int k, int ef_search)
{
  vvec_meta_t meta;
  float * vec = NULL;
  int dim = 0;
  float magnitude;
  vvec_search_metrics_t metrics;
  caddr_t ret;
  if (!key || !vvec_key_p (key))
    sqlr_new_error ("42000", "VEC02", "Index is not a vector index in %s.", func_name);
  dbe_key_open (key);
  if (!vvec_meta_from_key (key, &meta))
    sqlr_new_error ("42000", "VEC03", "Vector index %s has incomplete metadata.", key->key_name);
  vvec_require_healthy (qi, &meta, func_name);
  if (!vvec_extract_floats (query_vec, &vec, &dim))
    sqlr_new_error ("22023", "VEC33", "Malformed query vector for %s.", key->key_name);
  vvec_apply_reduction (&meta, &vec, &dim);
  if (dim != meta.vm_dimension)
    sqlr_new_error ("22023", "VEC34", "Query dimension %d does not match vector index dimension %d.", dim, meta.vm_dimension);
  if (k <= 0)
    k = 10;
  if (ef_search < k)
    ef_search = k;
  memset (&metrics, 0, sizeof (metrics));
  magnitude = vvec_vector_magnitude (vec, dim);
  ret = vvec_search_graph_and_pack (qi, &meta, vec, magnitude, k, ef_search, &metrics);
  dk_free ((caddr_t) vec, dim * sizeof (float));
  return ret;
}


/* M2: Cost model for vector index ANN access path.
 *
 * Estimates the cost of an ANN search on a vector index.
 * Uses metrics from the index root page if available:
 * - graph_nodes: total nodes in the HNSW graph
 * - search_count: number of searches performed
 * - search_usec: cumulative search time in microseconds
 *
 * Cost formula: ef_search * log2(graph_nodes) page visits * avg_search_time
 * Falls back to ef_search * 0.01ms when no history exists.
 *
 * The sqlo_vvec_ann_cost_bias factor (default 1.0) allows tests to force
 * ANN plans by lowering the cost artificially.
 */
float sqlo_vvec_ann_cost_bias = 1.0f;

int
vvec_ann_cost (dbe_key_t * key, int k, int ef_search, float *rows_out, float *cost_out)
{
  index_tree_t * it;
  buffer_desc_t * root = NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  int64 graph_nodes, search_count, search_usec;
  float avg_search_time, cost;

  if (!key || !vvec_key_p (key))
    return 0;
  if (!key->key_fragments || !key->key_fragments[0])
    return 0;
  it = key->key_fragments[0]->kf_it;
  if (!it)
    return 0;
  if (k <= 0)
    k = 10;
  if (ef_search < k)
    ef_search = k;
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, it);
  vvec_root_read (itc, it, PA_READ, &root);
  if (!root)
    return 0;
  graph_nodes = vvec_meta_ref_i64 (root, VVEC_META_TOTAL_NODES);
  search_count = vvec_meta_ref_i64 (root, VVEC_META_SEARCH_COUNT);
  search_usec = vvec_meta_ref_i64 (root, VVEC_META_SEARCH_USEC);
  vvec_page_release (itc, root);
  if (search_count > 0 && search_usec > 0)
    avg_search_time = (float) search_usec / (float) search_count / 1000.0f; /* convert to msec */
  else
    avg_search_time = ef_search * 0.01f; /* fallback: 0.01ms per ef_search */
  /* Cost: ef_search * log2(graph_nodes) * avg_search_time */
  if (graph_nodes > 1)
    cost = ef_search * (logf ((float) graph_nodes) / logf (2.0f)) * avg_search_time;
  else
    cost = ef_search * avg_search_time;
  /* Apply cost bias (default 1.0, tests can lower to force ANN) */
  cost *= sqlo_vvec_ann_cost_bias;
  *rows_out = (float) k;
  *cost_out = cost;
  return 1;
}


int
sqlo_vvec_require_ann_for_client (client_connection_t *cli)
{
  caddr_t name = (caddr_t) VVEC_REQUIRE_ANN_CLI_VAR;
  caddr_t *place;

  if (!cli || !cli->cli_globals)
    return 0;
  place = (caddr_t *) id_hash_get (cli->cli_globals, (caddr_t) &name);
  if (!place || DV_DB_NULL == DV_TYPE_OF (*place))
    return 0;
  return unbox (*place) ? 1 : 0;
}


int
sqlo_vvec_filter_mode_for_client (client_connection_t *cli)
{
  caddr_t name = (caddr_t) VVEC_FILTER_MODE_CLI_VAR;
  caddr_t *place;
  int mode;

  if (!cli || !cli->cli_globals)
    return VVEC_FILTER_MODE_AUTO;
  place = (caddr_t *) id_hash_get (cli->cli_globals, (caddr_t) &name);
  if (!place || DV_DB_NULL == DV_TYPE_OF (*place))
    return VVEC_FILTER_MODE_AUTO;
  mode = (int) unbox (*place);
  if (mode < VVEC_FILTER_MODE_AUTO || mode > VVEC_FILTER_MODE_ANN)
    return VVEC_FILTER_MODE_AUTO;
  return mode;
}


static caddr_t
bif_vvec_search (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_SEARCH");
  caddr_t query_vec = bif_arg (qst, args, 1, "__VEC_INDEX_SEARCH");
  int k = bif_long_arg (qst, args, 2, "__VEC_INDEX_SEARCH");
  int ef_search = bif_long_arg (qst, args, 3, "__VEC_INDEX_SEARCH");
  return vvec_search_run (qi, "__VEC_INDEX_SEARCH", index_name, query_vec, k, ef_search);
}


/* Development-only BIF: exercises the same executor kernel as __VEC_INDEX_SEARCH
 * but through the vvec_search_run entry point that phase-2 optimizer rewrites
 * route through.  Used by tvvec_ann_equiv.sql to prove executor parity before
 * the automatic plan rewriter (M3) is fully wired. */
static caddr_t
bif_vvec_ann_plan (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name = bif_string_arg (qst, args, 0, "__vvec_ann_plan");
  caddr_t query_vec = bif_arg (qst, args, 1, "__vvec_ann_plan");
  int k = BOX_ELEMENTS (args) > 2 ? bif_long_arg (qst, args, 2, "__vvec_ann_plan") : 10;
  int ef_search = BOX_ELEMENTS (args) > 3 ? bif_long_arg (qst, args, 3, "__vvec_ann_plan") : 0;
  return vvec_search_run (qi, "__vvec_ann_plan", index_name, query_vec, k, ef_search);
}


/* __vvec_page_image_peak (reset) -> the high-water mark of DPF_VEC pages held
   in flight by a single transaction, in pages; multiply by the page size for
   the bytes it cost.  A non-zero RESET puts the mark back to zero after
   reading it, so that a following operation can be measured on its own.

   The number is bounded by what a transaction has open between allocating or
   snapshotting a page and releasing it, not by how many pages it writes in
   total -- which is the property tvvec_page_log.sh asserts, and the one an
   operator wants to be able to check on a server doing large rebuilds. */
static caddr_t
bif_vvec_page_image_peak (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int64 peak;
  int reset = BOX_ELEMENTS (args) > 0
      ? (int) bif_long_arg (qst, args, 0, "__vvec_page_image_peak") : 0;
  (void) err_ret;
  peak = vvec_page_image_peak;
  if (reset)
    vvec_page_image_peak = 0;
  return box_num (peak);
}


static caddr_t
bif_vvec_search_test_embedding (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  vvec_meta_t meta;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_SEARCH_TEST_EMBEDDING");
  int pos1 = bif_long_arg (qst, args, 1, "__VEC_INDEX_SEARCH_TEST_EMBEDDING");
  int pos2 = bif_long_arg (qst, args, 2, "__VEC_INDEX_SEARCH_TEST_EMBEDDING");
  int k = bif_long_arg (qst, args, 3, "__VEC_INDEX_SEARCH_TEST_EMBEDDING");
  int ef_search = bif_long_arg (qst, args, 4, "__VEC_INDEX_SEARCH_TEST_EMBEDDING");
  caddr_t query_vec;
  caddr_t ret;
  vvec_require_key (qi, "__VEC_INDEX_SEARCH_TEST_EMBEDDING", index_name, &meta);
  query_vec = vvec_make_test_vector_box (meta.vm_dimension, pos1, pos2);
  ret = vvec_search_run (qi, "__VEC_INDEX_SEARCH_TEST_EMBEDDING", index_name, query_vec, k, ef_search);
  dk_free_tree (query_vec);
  return ret;
}


static caddr_t
bif_vvec_metrics (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  vvec_meta_t meta;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_METRICS");
  buffer_desc_t * root = NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  caddr_t ret;
  vvec_require_key (qi, "__VEC_INDEX_METRICS", index_name, &meta);
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta.vm_it);
  vvec_root_read (itc, meta.vm_it, PA_READ, &root);
  ret = vvec_metrics_box (root, &meta);
  vvec_page_release (itc, root);
  return ret;
}


static caddr_t
bif_vvec_page_stats (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  vvec_meta_t meta;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_PAGE_STATS");
  buffer_desc_t * root = NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  caddr_t ret;
  vvec_require_key (qi, "__VEC_INDEX_PAGE_STATS", index_name, &meta);
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta.vm_it);
  vvec_root_read (itc, meta.vm_it, PA_READ, &root);
  ret = vvec_page_stats_box (root, &meta, itc);
  vvec_page_release (itc, root);
  return ret;
}


/* Force reconciliation to run again for one index.
 *
 * The verdict is normally cached for the life of the process, because the
 * divergence it looks for is created by a crash and therefore only becomes
 * visible at startup.  Divergence introduced *during* a session -- a rolled
 * back transaction that had already mutated the graph -- would otherwise go
 * unnoticed until the next restart.  This is the operator's handle for that
 * case, and the hook the durability tests use to exercise the read guard.
 */
static caddr_t
bif_vvec_health_recheck (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  vvec_meta_t meta;
  dk_mutex_t * wmtx;
  int undone = 0;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_HEALTH_RECHECK");
  vvec_require_key (qi, "__VEC_INDEX_HEALTH_RECHECK", index_name, &meta);
  wmtx = vvec_writer_lock (meta.vm_it);
  QR_RESET_CTX_T (qi->qi_thread)
    {
      undone = vvec_undo_apply (qi, &meta);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      vvec_writer_unlock (wmtx);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  vvec_writer_unlock (wmtx);
  if (undone)
    vvec_write_epoch_sync (qi, &meta);
  vvec_health_set (meta.vm_key->key_id, VVEC_HEALTH_UNCHECKED);
  return box_num (vvec_epoch_reconcile (qi, &meta));
}


static caddr_t
bif_vvec_rebuild (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  int nargs = BOX_ELEMENTS (args);
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_REBUILD");
  /* Optional per-call overrides: __VEC_INDEX_REBUILD(idx [, method [, threads]]).
     method in {'replay','fast','auto'}; threads is a positive int (fast only). */
  int method_override = VVEC_REBUILD_UNSET;
  int threads_override = 0;
  if (nargs > 1)
    {
      caddr_t m = bif_arg (qst, args, 1, "__VEC_INDEX_REBUILD");
      if (vvec_is_string_box (m))
	{
	  method_override = vvec_parse_rebuild (m);
	  if (method_override < 0)
	    sqlr_new_error ("42000", "VEC81",
		"__VEC_INDEX_REBUILD method must be 'replay', 'fast' or 'auto'.");
	}
    }
  if (nargs > 2)
    threads_override = (int) bif_long_arg (qst, args, 2, "__VEC_INDEX_REBUILD");
  return vvec_rebuild_impl (qi, "__VEC_INDEX_REBUILD", index_name, method_override, threads_override);
}


static caddr_t
bif_vvec_validate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  vvec_meta_t meta;
  char * index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_VALIDATE");
  local_cursor_t * lc = NULL;
  query_t * qr = NULL;
  int tested = 0;
  int condemned;
  double recall_sum = 0;
  vvec_require_key (qi, "__VEC_INDEX_VALIDATE", index_name, &meta);
  /* An index whose redo recovery could not apply is not walkable: the records
     that were skipped leave references to pages nothing ever wrote, and
     sampling recall over it raises VEC60 from somewhere three layers down
     rather than saying what is wrong.  Report it instead.  Deliberately
     without repairing, and without consuming the mark -- validate is a
     diagnostic, and one that could start an hours-long rebuild on a large
     index would be a trap.  The rebuild happens when the index is next
     actually used, through vvec_require_healthy (). */
  condemned = vvec_replay_condemned_p (meta.vm_key->key_id);
  vvec_hidden_foreach (qi, meta.vm_hidden_table, &lc, &qr);
  while (!condemned && lc_next (lc) && tested < 10)
    {
      caddr_t embedding = lc_nth_col (lc, 1);
      float * vec = NULL;
      int dim = 0;
      float magnitude;
      vvec_cand_list_t ann;
      vvec_search_metrics_t metrics;
      local_cursor_t * lc_exact = NULL;
      query_t * qr_exact = NULL;
      vvec_cand_list_t exact;
      if (!vvec_extract_floats (embedding, &vec, &dim))
	continue;
      vvec_apply_reduction (&meta, &vec, &dim);
      if (dim != meta.vm_dimension)
	{
	  dk_free ((caddr_t) vec, dim * sizeof (float));
	  continue;
	}
      magnitude = vvec_vector_magnitude (vec, dim);
      memset (&metrics, 0, sizeof (metrics));
      vvec_search_graph_for_validate (qi, &meta, vec, magnitude, 10, 50, &ann, &metrics);
      vvec_cand_list_init (&exact, 16);
      vvec_hidden_foreach (qi, meta.vm_hidden_table, &lc_exact, &qr_exact);
      while (lc_next (lc_exact))
	{
	  caddr_t emb2 = lc_nth_col (lc_exact, 1);
	  float * vec2 = NULL;
	  int dim2 = 0;
	  if (vvec_extract_floats (emb2, &vec2, &dim2))
	    {
	      vvec_apply_reduction (&meta, &vec2, &dim2);
	      if (dim2 == dim)
		{
		  dp_addr_t exact_dp = 0;
		  float dist = vvec_distance_inline (vec, magnitude, vec2, vvec_vector_magnitude (vec2, dim2), dim, meta.vm_metric);
		  if (vvec_hidden_lookup_existing (qi, &meta, lc_nth_col (lc_exact, 0), &exact_dp))
		    vvec_cand_list_insert (&exact, exact_dp, dist);
		}
	      dk_free ((caddr_t) vec2, dim2 * sizeof (float));
	    }
	}
      lc_free (lc_exact);
      qr_free (qr_exact);
      if (exact.vcl_fill > 10)
	exact.vcl_fill = 10;
      if (exact.vcl_fill)
	{
	  int hit = 0;
	  int i, j;
	  for (i = 0; i < ann.vcl_fill; i++)
	    for (j = 0; j < exact.vcl_fill; j++)
	      if (ann.vcl_items[i].vc_dp == exact.vcl_items[j].vc_dp)
		{
		  hit++;
		  break;
		}
	  recall_sum += ((double) hit) / ((double) exact.vcl_fill);
	  tested++;
	}
	      vvec_cand_list_free (&exact);
	      vvec_cand_list_free (&ann);
	      dk_free ((caddr_t) vec, dim * sizeof (float));
	    }
  lc_free (lc);
  qr_free (qr);
  {
    /* Durability check.  Report divergence rather than quietly returning a
       recall figure measured against a graph that no longer describes the
       data -- that number would look fine and mean nothing.  */
    int64 graph_epoch = vvec_root_epoch_ref (qi, &meta);
    int found = 0;
    int64 data_epoch = vvec_catalog_epoch_ref (qi, &meta, &found);
    int64 hidden_rows = vvec_hidden_row_count (qi, &meta);
    int64 active_nodes;
    int consistent;
    const char * detail;
    {
      it_cursor_t itc_auto;
      it_cursor_t * itc = &itc_auto;
      buffer_desc_t * root = NULL;
      ITC_INIT (itc, NULL, qi->qi_trx);
      itc_from_it (itc, meta.vm_it);
      vvec_root_read (itc, meta.vm_it, PA_READ, &root);
      active_nodes = vvec_meta_ref_i64 (root, VVEC_META_ACTIVE_NODES);
      vvec_page_release (itc, root);
    }
    if (condemned)
      { consistent = 0; detail = "recovery could not replay part of the graph, so it is behind the data "
	    "(the pages it names were no longer the index's); it is rebuilt from the stored embeddings on first use"; }
    else if (found && graph_epoch < data_epoch)
      { consistent = 0; detail = "graph is behind the data (mutations lost, likely an unclean shutdown)"; }
    else if (found && graph_epoch > data_epoch)
      { consistent = 0; detail = "graph is ahead of the data (rolled-back transaction left orphan nodes)"; }
    else if (hidden_rows >= 0 && hidden_rows != active_nodes)
      { consistent = 0; detail = "live node count does not match the stored embedding count"; }
    else
      { consistent = 1; detail = "graph agrees with the stored embeddings"; }

    caddr_t * ret = (caddr_t *) dk_alloc_box (20 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    ret[0] = box_dv_short_string ("queries_tested");
    ret[1] = box_num (tested);
    ret[2] = box_dv_short_string ("recall_at_10");
    ret[3] = box_double (tested ? recall_sum / ((double) tested) : 1.0);
    ret[4] = box_dv_short_string ("distance_metric");
    ret[5] = box_dv_short_string ((char *) vvec_metric_name (meta.vm_metric));
    ret[6] = box_dv_short_string ("dimension");
    ret[7] = box_num (meta.vm_dimension);
    ret[8] = box_dv_short_string ("consistent");
    ret[9] = box_num (consistent);
    ret[10] = box_dv_short_string ("consistency_detail");
    ret[11] = box_dv_short_string ((char *) detail);
    ret[12] = box_dv_short_string ("graph_epoch");
    ret[13] = box_num (graph_epoch);
    ret[14] = box_dv_short_string ("data_epoch");
    ret[15] = found ? box_num (data_epoch) : NEW_DB_NULL;
    ret[16] = box_dv_short_string ("active_nodes");
    ret[17] = box_num (active_nodes);
    ret[18] = box_dv_short_string ("embedding_rows");
    ret[19] = hidden_rows >= 0 ? box_num (hidden_rows) : NEW_DB_NULL;
    return (caddr_t) ret;
  }
}


static caddr_t
bif_vector_distance (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  caddr_t v1;
  caddr_t v2;
  caddr_t metric_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "VECTOR_DISTANCE") : NULL;
  float *f1 = NULL, *f2 = NULL;
  int d1 = 0, d2 = 0;
  float res;
  int metric;

  if (BOX_ELEMENTS (args) < 2 || BOX_ELEMENTS (args) > 3)
    sqlr_new_error ("22023", "VEC47", "VECTOR_DISTANCE expects 2 or 3 arguments.");
  v1 = bif_arg (qst, args, 0, "VECTOR_DISTANCE");
  v2 = bif_arg (qst, args, 1, "VECTOR_DISTANCE");
  if (vvec_arg_is_db_null (v1) || vvec_arg_is_db_null (v2))
    return NEW_DB_NULL;
  metric = vvec_metric_from_arg (metric_arg, VVEC_METRIC_COSINE, "VECTOR_DISTANCE");
  if (!vvec_extract_floats (v1, &f1, &d1) || !vvec_extract_floats (v2, &f2, &d2))
    {
      if (f1) dk_free ((caddr_t) f1, d1 * sizeof (float));
      if (f2) dk_free ((caddr_t) f2, d2 * sizeof (float));
      sqlr_new_error ("22023", "VEC45", "Invalid arguments for VECTOR_DISTANCE");
    }
  if (d1 != d2)
    {
      dk_free ((caddr_t) f1, d1 * sizeof (float));
      dk_free ((caddr_t) f2, d2 * sizeof (float));
      sqlr_new_error ("22023", "VEC44", "Vector dimensions %d and %d do not match in VECTOR_DISTANCE.", d1, d2);
    }
  res = vvec_distance_inline (f1, vvec_vector_magnitude (f1, d1), f2, vvec_vector_magnitude (f2, d2), d1, metric);
  dk_free ((caddr_t) f1, d1 * sizeof (float));
  dk_free ((caddr_t) f2, d2 * sizeof (float));
  return box_float (res);
}


static caddr_t
bif_vvec_row_distance (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  query_instance_t * qi = (query_instance_t *) qst;
  char * index_name;
  caddr_t row_id;
  caddr_t query_vec;
  caddr_t metric_arg = NULL;
  vvec_meta_t meta;
  float * vec = NULL;
  int dim = 0;
  float magnitude;
  float distance;
  int64 row_id_i64 = 0;
  int metric;
  dp_addr_t node_dp = 0;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;

  if (BOX_ELEMENTS (args) < 3 || BOX_ELEMENTS (args) > 4)
    sqlr_new_error ("22023", "VEC48", "__VEC_INDEX_ROW_DISTANCE expects 3 to 4 arguments.");
  index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_ROW_DISTANCE");
  row_id = bif_arg (qst, args, 1, "__VEC_INDEX_ROW_DISTANCE");
  query_vec = bif_arg (qst, args, 2, "__VEC_INDEX_ROW_DISTANCE");
  if (BOX_ELEMENTS (args) > 3)
    metric_arg = bif_arg (qst, args, 3, "__VEC_INDEX_ROW_DISTANCE");

  if (vvec_arg_is_db_null (row_id) || vvec_arg_is_db_null (query_vec))
    return NEW_DB_NULL;

  vvec_require_key (qi, "__VEC_INDEX_ROW_DISTANCE", index_name, &meta);
  metric = vvec_metric_from_arg (metric_arg, meta.vm_metric, "__VEC_INDEX_ROW_DISTANCE");
  if (metric != meta.vm_metric)
    sqlr_new_error ("22023", "VEC46",
	"Requested vector metric %s does not match vector index %s metric %s.",
	vvec_metric_name (metric), index_name, vvec_metric_name (meta.vm_metric));
  if (!vvec_extract_floats (query_vec, &vec, &dim))
    sqlr_new_error ("22023", "VEC33", "Malformed query vector for %s.", index_name);
  vvec_apply_reduction (&meta, &vec, &dim);
  if (dim != meta.vm_dimension)
    {
      dk_free ((caddr_t) vec, dim * sizeof (float));
      sqlr_new_error ("22023", "VEC34", "Query dimension %d does not match vector index dimension %d.", dim, meta.vm_dimension);
    }
  if (!vvec_row_id_to_i64 (row_id, &row_id_i64))
    {
      dk_free ((caddr_t) vec, dim * sizeof (float));
      sqlr_new_error ("22023", "VEC35", "Vector index row id for %s must be an integer value.", index_name);
    }
  (void) row_id_i64;
  if (!vvec_hidden_lookup_existing (qi, &meta, row_id, &node_dp))
    {
      dk_free ((caddr_t) vec, dim * sizeof (float));
      return NEW_DB_NULL;
    }

  magnitude = vvec_vector_magnitude (vec, dim);
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from_it (itc, meta.vm_it);
  distance = vvec_page_distance (itc, &meta, node_dp, vec, magnitude, 0, NULL);
  dk_free ((caddr_t) vec, dim * sizeof (float));
  return box_float (distance);
}


static float
vvec_similarity_from_distance (float distance, int metric)
{
  float similarity;
  switch (metric)
    {
    case VVEC_METRIC_COSINE:
      similarity = 1.0f - (distance / 2.0f);
      break;
    case VVEC_METRIC_L2:
    case VVEC_METRIC_L1:
      similarity = 1.0f / (1.0f + distance);
      break;
    default:
      similarity = 1.0f - distance;
      break;
    }
  if (similarity < 0)
    similarity = 0;
  if (similarity > 1)
    similarity = 1;
  return similarity;
}


static caddr_t
bif_vvec_row_similarity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  char *index_name = bif_string_arg (qst, args, 0, "__VEC_INDEX_ROW_SIMILARITY");
  caddr_t metric_arg = BOX_ELEMENTS (args) > 3 ? bif_arg (qst, args, 3, "__VEC_INDEX_ROW_SIMILARITY") : NULL;
  caddr_t distance_box = bif_vvec_row_distance (qst, err_ret, args);
  vvec_meta_t meta;
  int metric;
  float distance;

  if (DV_DB_NULL == DV_TYPE_OF (distance_box))
    return distance_box;
  vvec_require_key (qi, "__VEC_INDEX_ROW_SIMILARITY", index_name, &meta);
  metric = vvec_metric_from_arg (metric_arg, meta.vm_metric, "__VEC_INDEX_ROW_SIMILARITY");
  if (metric != meta.vm_metric)
    sqlr_new_error ("22023", "VEC63",
	"Requested vector metric %s does not match vector index %s metric %s.",
	vvec_metric_name (metric), index_name, vvec_metric_name (meta.vm_metric));
  distance = unbox_float (distance_box);
  dk_free_tree (distance_box);
  return box_float (vvec_similarity_from_distance (distance, metric));
}


/* DOT_PRODUCT / INNER_PRODUCT: the raw inner product of two vectors.
 *
 * Deliberately a similarity, not a distance, and deliberately not offered as an
 * index metric.  It is unbounded and larger-is-closer, and both of those fight
 * this engine's model: a search score is derived from the distance into [0,1]
 * (vvec_similarity_from_distance; VEC_INDEX_DISTANCE_TO_SCORE for SPARQL), and
 * VEC_INDEX_VALIDATE_SEARCH_OPTIONS bounds score_limit to [0,1], so a raw inner
 * product would produce scores outside every range the surrounding code
 * accepts.  Maximum-inner-product search over an HNSW
 * graph also needs care that plain cosine does not.  Callers who want inner
 * product ranking from the index should normalise their vectors, for which
 * cosine and inner product coincide -- and cosine is already the default.
 *
 * The kernel is the same SIMD one cosine is built on, so this costs nothing new. */
static caddr_t
bif_dot_product (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  caddr_t v1 = bif_arg (qst, args, 0, "DOT_PRODUCT");
  caddr_t v2 = bif_arg (qst, args, 1, "DOT_PRODUCT");
  float *f1 = NULL, *f2 = NULL;
  int d1 = 0, d2 = 0;
  float res;
  if (!vvec_extract_floats (v1, &f1, &d1) || !vvec_extract_floats (v2, &f2, &d2) || d1 != d2)
    {
      if (f1) dk_free ((caddr_t) f1, d1 * sizeof (float));
      if (f2) dk_free ((caddr_t) f2, d2 * sizeof (float));
      sqlr_new_error ("22023", "VEC40", "Invalid arguments for DOT_PRODUCT");
    }
  res = vvec_ip_f32 (f1, f2, d1);
  dk_free ((caddr_t) f1, d1 * sizeof (float));
  dk_free ((caddr_t) f2, d2 * sizeof (float));
  return box_float (res);
}


/* ---------- Vector arithmetic ----------
 *
 * These carry the names the 2.0 VVEC plugin used (VVEC_ADD, VVEC_SUBTRACT,
 * VVEC_DIVIDE, VVEC_SCALAR_MULTIPLY, VVEC_SCALAR_DIVIDE, VVEC_NORMALIZE,
 * VVEC_DIMENSION) so queries written against it keep working; VVEC_MULTIPLY is
 * added for symmetry with the elementwise divide the original shipped without
 * its counterpart.
 *
 * Results are DV_ARRAY_OF_FLOAT, which vvec_extract_floats accepts, so they
 * compose: DOT_PRODUCT (VVEC_NORMALIZE (a), VVEC_NORMALIZE (b)) is the cosine
 * similarity of a and b.
 *
 * Division by zero raises rather than producing inf/NaN.  A NaN that escaped
 * into a vector would not fail where it was made -- it would silently poison
 * every later distance computation and quietly corrupt search results. */

static caddr_t
vvec_floats_to_box (const float * v, int dim)
{
  float * out = (float *) dk_alloc_box (dim * sizeof (float), DV_ARRAY_OF_FLOAT);
  memcpy (out, v, dim * sizeof (float));
  return (caddr_t) out;
}


static void
vvec_arith_two_args (caddr_t * qst, state_slot_t ** args, const char * fn,
    float ** a_ret, float ** b_ret, int * dim_ret)
{
  caddr_t v1 = bif_arg (qst, args, 0, (char *) fn);
  caddr_t v2 = bif_arg (qst, args, 1, (char *) fn);
  float *f1 = NULL, *f2 = NULL;
  int d1 = 0, d2 = 0;
  if (!vvec_extract_floats (v1, &f1, &d1) || !vvec_extract_floats (v2, &f2, &d2) || d1 != d2)
    {
      if (f1) dk_free ((caddr_t) f1, d1 * sizeof (float));
      if (f2) dk_free ((caddr_t) f2, d2 * sizeof (float));
      sqlr_new_error ("22023", "VEC40",
          "Invalid arguments for %.100s: two vectors of equal dimension are required.", fn);
    }
  *a_ret = f1;
  *b_ret = f2;
  *dim_ret = d1;
}


static float *
vvec_arith_one_arg (caddr_t * qst, state_slot_t ** args, const char * fn, int * dim_ret)
{
  caddr_t v1 = bif_arg (qst, args, 0, (char *) fn);
  float * f1 = NULL;
  int d1 = 0;
  if (!vvec_extract_floats (v1, &f1, &d1))
    {
      if (f1) dk_free ((caddr_t) f1, d1 * sizeof (float));
      sqlr_new_error ("22023", "VEC40", "Invalid arguments for %.100s: a vector is required.", fn);
    }
  *dim_ret = d1;
  return f1;
}


#define VVEC_ELEMENTWISE_BIF(cfn, sqlname, expr)                             \
static caddr_t                                                               \
cfn (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)                 \
{                                                                            \
  float *a = NULL, *b = NULL;                                                \
  int dim = 0, i;                                                            \
  caddr_t res;                                                               \
  (void) err_ret;                                                            \
  vvec_arith_two_args (qst, args, sqlname, &a, &b, &dim);                    \
  for (i = 0; i < dim; i++)                                                  \
    {                                                                        \
      expr;                                                                  \
    }                                                                        \
  res = vvec_floats_to_box (a, dim);                                         \
  dk_free ((caddr_t) a, dim * sizeof (float));                               \
  dk_free ((caddr_t) b, dim * sizeof (float));                               \
  return res;                                                                \
}

VVEC_ELEMENTWISE_BIF (bif_vvec_add, "VVEC_ADD", a[i] = a[i] + b[i])
VVEC_ELEMENTWISE_BIF (bif_vvec_subtract, "VVEC_SUBTRACT", a[i] = a[i] - b[i])
VVEC_ELEMENTWISE_BIF (bif_vvec_multiply, "VVEC_MULTIPLY", a[i] = a[i] * b[i])
VVEC_ELEMENTWISE_BIF (bif_vvec_divide, "VVEC_DIVIDE",
    do {
      if (0.0f == b[i])
        {
          dk_free ((caddr_t) a, dim * sizeof (float));
          dk_free ((caddr_t) b, dim * sizeof (float));
          sqlr_new_error ("22012", "VEC41", "VVEC_DIVIDE by zero at element %d.", i);
        }
      a[i] = a[i] / b[i];
    } while (0))


static caddr_t
bif_vvec_scalar_multiply (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  float * a;
  int dim = 0, i;
  double k;
  caddr_t res;
  (void) err_ret;
  a = vvec_arith_one_arg (qst, args, "VVEC_SCALAR_MULTIPLY", &dim);
  k = bif_double_arg (qst, args, 1, "VVEC_SCALAR_MULTIPLY");
  for (i = 0; i < dim; i++)
    a[i] = (float) (a[i] * k);
  res = vvec_floats_to_box (a, dim);
  dk_free ((caddr_t) a, dim * sizeof (float));
  return res;
}


static caddr_t
bif_vvec_scalar_divide (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  float * a;
  int dim = 0, i;
  double k;
  caddr_t res;
  (void) err_ret;
  a = vvec_arith_one_arg (qst, args, "VVEC_SCALAR_DIVIDE", &dim);
  k = bif_double_arg (qst, args, 1, "VVEC_SCALAR_DIVIDE");
  if (0.0 == k)
    {
      dk_free ((caddr_t) a, dim * sizeof (float));
      sqlr_new_error ("22012", "VEC41", "VVEC_SCALAR_DIVIDE by zero.");
    }
  for (i = 0; i < dim; i++)
    a[i] = (float) (a[i] / k);
  res = vvec_floats_to_box (a, dim);
  dk_free ((caddr_t) a, dim * sizeof (float));
  return res;
}


static caddr_t
bif_vvec_normalize (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  float * a;
  int dim = 0, i;
  float mag;
  caddr_t res;
  (void) err_ret;
  a = vvec_arith_one_arg (qst, args, "VVEC_NORMALIZE", &dim);
  mag = vvec_vector_magnitude (a, dim);
  if (0.0f == mag)
    {
      dk_free ((caddr_t) a, dim * sizeof (float));
      sqlr_new_error ("22012", "VEC41", "VVEC_NORMALIZE of a zero vector has no direction.");
    }
  for (i = 0; i < dim; i++)
    a[i] = a[i] / mag;
  res = vvec_floats_to_box (a, dim);
  dk_free ((caddr_t) a, dim * sizeof (float));
  return res;
}


static caddr_t
bif_vvec_dimension (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  float * a;
  int dim = 0;
  (void) err_ret;
  a = vvec_arith_one_arg (qst, args, "VVEC_DIMENSION", &dim);
  dk_free ((caddr_t) a, dim * sizeof (float));
  return box_num (dim);
}


/* INNER_PRODUCT is a spelling of DOT_PRODUCT, but it needs its own entry point:
 * bif_define rejects the same function pointer under two names. */
static caddr_t
bif_inner_product (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_dot_product (qst, err_ret, args);
}


/* The Euclidean length of a vector -- the companion DOT_PRODUCT needs to be
 * useful, since cosine(a,b) is DOT_PRODUCT(a,b) / (NORM(a) * NORM(b)) and
 * normalising is what makes inner product and cosine agree. */
static caddr_t
bif_vector_norm (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  caddr_t v1 = bif_arg (qst, args, 0, "VECTOR_NORM");
  float *f1 = NULL;
  int d1 = 0;
  float res;
  if (!vvec_extract_floats (v1, &f1, &d1))
    {
      if (f1) dk_free ((caddr_t) f1, d1 * sizeof (float));
      sqlr_new_error ("22023", "VEC40", "Invalid arguments for VECTOR_NORM");
    }
  res = vvec_vector_magnitude (f1, d1);
  dk_free ((caddr_t) f1, d1 * sizeof (float));
  return box_float (res);
}


/* __VEC_IDENTITY (x) -- returns x unchanged.
 *
 * Used to wrap a reference to ot_vec_similarity's virtual column: the
 * optimizer needs the rewritten X_SIMILAR() predicate to stay a CALL_STMT
 * (sqlo_rewrite_x_similar_call and sqlg_vvec_search_node both only ever
 * mutate a CALL_STMT's own name/params in place, an established, low-risk
 * pattern already used for the __VEC_INDEX_ROW_SIMILARITY /
 * __VEC_INDEX_ROW_DISTANCE rewrites elsewhere in this file), rather than
 * reshaping it into a different tree type (e.g. COL_DOTTED) in place, which
 * would be new, unproven, and higher-risk for no real benefit: this call
 * costs one indirection, not a row re-fetch or a distance recompute. */
static caddr_t
bif_vvec_identity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  return box_copy_tree (bif_arg (qst, args, 0, "__VEC_IDENTITY"));
}


/* Convert a stored embedding to the flat form, for migrating an index built
   before DV_ARRAY_OF_FLOAT became the stored form.  Optional: readers accept
   both, so an unconverted table keeps working. */
static caddr_t
bif_vvec_to_float_vector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t vec = bif_arg (qst, args, 0, "VVEC_TO_FLOAT_VECTOR");
  caddr_t box;
  (void) err_ret;
  if (!vec || DV_DB_NULL == DV_TYPE_OF (vec))
    return NEW_DB_NULL;
  box = vvec_to_float_box (vec);
  if (!box)
    sqlr_new_error ("22023", "VEC30", "VVEC_TO_FLOAT_VECTOR argument is not an embedding vector.");
  return box;
}


static caddr_t
bif_cosine_distance (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  caddr_t v1 = bif_arg (qst, args, 0, "COSINE_DISTANCE");
  caddr_t v2 = bif_arg (qst, args, 1, "COSINE_DISTANCE");
  float *f1 = NULL, *f2 = NULL;
  int d1 = 0, d2 = 0;
  float res;
  if (!vvec_extract_floats (v1, &f1, &d1) || !vvec_extract_floats (v2, &f2, &d2) || d1 != d2)
    {
      if (f1) dk_free ((caddr_t)f1, d1 * sizeof(float));
      if (f2) dk_free ((caddr_t)f2, d2 * sizeof(float));
      sqlr_new_error ("22023", "VEC40", "Invalid arguments for COSINE_DISTANCE");
    }
  res = vvec_distance_inline (f1, vvec_vector_magnitude (f1, d1), f2, vvec_vector_magnitude (f2, d2), d1, VVEC_METRIC_COSINE);
  dk_free ((caddr_t)f1, d1 * sizeof(float));
  dk_free ((caddr_t)f2, d2 * sizeof(float));
  return box_float (res);
}


static caddr_t
bif_l1_distance (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  caddr_t v1 = bif_arg (qst, args, 0, "L1_DISTANCE");
  caddr_t v2 = bif_arg (qst, args, 1, "L1_DISTANCE");
  float *f1 = NULL, *f2 = NULL;
  int d1 = 0, d2 = 0;
  float res;
  if (!vvec_extract_floats (v1, &f1, &d1) || !vvec_extract_floats (v2, &f2, &d2) || d1 != d2)
    {
      if (f1) dk_free ((caddr_t)f1, d1 * sizeof(float));
      if (f2) dk_free ((caddr_t)f2, d2 * sizeof(float));
      sqlr_new_error ("22023", "VEC41", "Invalid arguments for L1_DISTANCE");
    }
  res = vvec_distance_inline (f1, 0, f2, 0, d1, VVEC_METRIC_L1);
  dk_free ((caddr_t)f1, d1 * sizeof(float));
  dk_free ((caddr_t)f2, d2 * sizeof(float));
  return box_float (res);
}


static caddr_t
bif_l2_distance (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  caddr_t v1 = bif_arg (qst, args, 0, "L2_DISTANCE");
  caddr_t v2 = bif_arg (qst, args, 1, "L2_DISTANCE");
  float *f1 = NULL, *f2 = NULL;
  int d1 = 0, d2 = 0;
  float res;
  if (!vvec_extract_floats (v1, &f1, &d1) || !vvec_extract_floats (v2, &f2, &d2) || d1 != d2)
    {
      if (f1) dk_free ((caddr_t)f1, d1 * sizeof(float));
      if (f2) dk_free ((caddr_t)f2, d2 * sizeof(float));
      sqlr_new_error ("22023", "VEC42", "Invalid arguments for L2_DISTANCE");
    }
  res = vvec_distance_inline (f1, 0, f2, 0, d1, VVEC_METRIC_L2);
  dk_free ((caddr_t)f1, d1 * sizeof(float));
  dk_free ((caddr_t)f2, d2 * sizeof(float));
  return box_float (res);
}


/* M4: X_SIMILAR BIF - returns similarity score in [0, 1] range
 * X_SIMILAR(v1, v2 [, metric]) returns a similarity score where:
 * - 1.0 means identical vectors
 * - 0.0 means completely dissimilar (orthogonal for cosine)
 *
 * For cosine metric: similarity = 1 - (cosine_distance / 2)
 * For L2 metric: similarity = 1 / (1 + l2_distance)
 * For L1 metric: similarity = 1 / (1 + l1_distance)
 */
static caddr_t
bif_x_similar (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  caddr_t v1;
  caddr_t v2;
  caddr_t metric_arg = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "X_SIMILAR") : NULL;
  float *f1 = NULL, *f2 = NULL;
  int d1 = 0, d2 = 0;
  float distance;
  float similarity;
  int metric;

  if (BOX_ELEMENTS (args) < 2 || BOX_ELEMENTS (args) > 3)
    sqlr_new_error ("22023", "VEC60", "X_SIMILAR expects 2 or 3 arguments.");
  v1 = bif_arg (qst, args, 0, "X_SIMILAR");
  v2 = bif_arg (qst, args, 1, "X_SIMILAR");
  if (vvec_arg_is_db_null (v1) || vvec_arg_is_db_null (v2))
    return NEW_DB_NULL;
  metric = vvec_metric_from_arg (metric_arg, VVEC_METRIC_COSINE, "X_SIMILAR");
  if (!vvec_extract_floats (v1, &f1, &d1) || !vvec_extract_floats (v2, &f2, &d2))
    {
      if (f1) dk_free ((caddr_t) f1, d1 * sizeof (float));
      if (f2) dk_free ((caddr_t) f2, d2 * sizeof (float));
      sqlr_new_error ("22023", "VEC61", "Invalid arguments for X_SIMILAR");
    }
  if (d1 != d2)
    {
      dk_free ((caddr_t) f1, d1 * sizeof (float));
      dk_free ((caddr_t) f2, d2 * sizeof (float));
      sqlr_new_error ("22023", "VEC62", "Vector dimensions %d and %d do not match in X_SIMILAR.", d1, d2);
    }
  distance = vvec_distance_inline (f1, vvec_vector_magnitude (f1, d1), f2, vvec_vector_magnitude (f2, d2), d1, metric);
  dk_free ((caddr_t) f1, d1 * sizeof (float));
  dk_free ((caddr_t) f2, d2 * sizeof (float));

  similarity = vvec_similarity_from_distance (distance, metric);
  return box_float (similarity);
}


/* M3: Vector ANN search node implementation
 *
 * These functions provide the executor-side implementation for
 * vvec_search_node_t, which drives table scans via ANN index search.
 */

#include "xmlnode.h"

#define VSN_QST_SET(vsn, qst, ssl, value) \
  do { \
    if ((vsn)->src_gen.src_sets) \
      { \
	QNCAST (query_instance_t, set_qi, qst); \
	data_col_t *set_dc = QST_BOX (data_col_t *, qst, (ssl)->ssl_index); \
	int save_set = set_qi->qi_set; \
	set_qi->qi_set = set_dc->dc_n_values; \
	qst_vec_set (qst, ssl, value); \
	set_qi->qi_set = save_set; \
      } \
    else \
      qst_set (qst, ssl, value); \
  } while (0)

static int
vvec_rdf_row_id_cmp (const void * a, const void * b)
{
  int64 x = unbox (((caddr_t *) *(caddr_t *) a)[0]);
  int64 y = unbox (((caddr_t *) *(caddr_t *) b)[0]);
  return x < y ? -1 : x > y ? 1 : 0;
}


/* knnSimilar's least search breadth, bif:vector_search's default ef_search */
#define VEC_SIMILAR_MIN_EF 100

/* knnSimilar's k nearest literals for the current set's text and k, searched once and
   kept as (text, k, rows by distance, rows by RO_ID); each row is (RO_ID, distance). */
static caddr_t *
vvec_rdf_hits (vvec_search_node_t * vsn, caddr_t * inst)
{
  QNCAST (query_instance_t, qi, inst);
  caddr_t * cache = (caddr_t *) qst_get (inst, vsn->vsn_results);
  caddr_t text = qst_get (inst, vsn->vsn_query_text);
  int k = (int) unbox (qst_get (inst, vsn->vsn_k));
  int ef_search = (int) unbox (qst_get (inst, vsn->vsn_ef_search));
  caddr_t rows = NULL, by_id;
  if (k <= 0)
    k = VEC_SIMILAR_DEFAULT_K;
  if (cache && box_equal (cache[0], text) && unbox (cache[1]) == k)
    return cache;
  if (DV_STRINGP (text) || DV_WIDESTRINGP (text))
    {
      vvec_meta_t meta;
      caddr_t emb;
      vvec_require_key (qi, "knnSimilar", vsn->vsn_vec_key->key_name, &meta);
      emb = vvec_embed_text_for_model (qi, "knnSimilar", vsn->vsn_vec_key->key_name, &meta, text);
      /* with ef = k a small k stops at the first local optimum */
      rows = vvec_search_run_key (qi, "knnSimilar", vsn->vsn_vec_key, emb, k, MAX (MAX (k, ef_search), VEC_SIMILAR_MIN_EF));
      dk_free_tree (emb);
    }
  if (!IS_BOX_POINTER (rows) || DV_ARRAY_OF_POINTER != DV_TYPE_OF (rows))
    {
      dk_free_tree (rows);
      rows = dk_alloc_box (0, DV_ARRAY_OF_POINTER);
    }
  by_id = box_copy_tree (rows);
  if (BOX_ELEMENTS (by_id) > 1)
    qsort (by_id, BOX_ELEMENTS (by_id), sizeof (caddr_t), vvec_rdf_row_id_cmp);
  cache = (caddr_t *) list (4, box_copy_tree (text), box_num (k), rows, by_id);
  qst_set (inst, vsn->vsn_results, (caddr_t) cache);
  return cache;
}


static caddr_t *
vvec_rdf_find (caddr_t * by_id, int64 ro_id)
{
  int lo = 0, hi = (int) BOX_ELEMENTS (by_id) - 1;
  while (lo <= hi)
    {
      int mid = (lo + hi) / 2;
      int64 id = unbox (((caddr_t *) by_id[mid])[0]);
      if (id == ro_id)
	return (caddr_t *) by_id[mid];
      if (id < ro_id)
	lo = mid + 1;
      else
	hi = mid - 1;
    }
  return NULL;
}


/* The O of literal RO_ID, as the text node writes it for RDF_QUAD. */
static void
vvec_rdf_set_o (vvec_search_node_t * vsn, caddr_t * inst, int64 ro_id)
{
  if (vsn->src_gen.src_sets)
    {
      data_col_t * dc = QST_BOX (data_col_t *, inst, vsn->vsn_pk_id->ssl_index);
      dtp_t buf[9];
      int len;
      if (ro_id > (int64) 0x7fffffff)
	{
	  buf[0] = DV_RDF_ID_8;
	  INT64_SET_NA (&buf[1], ro_id);
	  len = 9;
	}
      else
	{
	  buf[0] = DV_RDF_ID;
	  LONG_SET_NA (&buf[1], (int32) ro_id);
	  len = 5;
	}
      dc_append_bytes (dc, buf, len, NULL, 0);
    }
  else
    qst_set (inst, vsn->vsn_pk_id, rbb_from_id (ro_id));
}


static void
vvec_rdf_set_score (vvec_search_node_t * vsn, caddr_t * inst, caddr_t dist_box)
{
  float d = 0;
  if (DV_DOUBLE_FLOAT == DV_TYPE_OF (dist_box))
    d = (float) unbox_double (dist_box);
  else if (DV_SINGLE_FLOAT == DV_TYPE_OF (dist_box))
    d = unbox_float (dist_box);
  if (vsn->vsn_distance)
    VSN_QST_SET (vsn, inst, vsn->vsn_distance, box_float (d));
  if (vsn->vsn_similarity)
    VSN_QST_SET (vsn, inst, vsn->vsn_similarity, box_float (vvec_similarity_from_distance (d, (int) vsn->vsn_metric)));
}


static int64
vvec_rdf_in_ro_id (vvec_search_node_t * vsn, caddr_t * inst)
{
  caddr_t v = qst_get (inst, vsn->vsn_ro_id);
  switch (DV_TYPE_OF (v))
    {
    case DV_LONG_INT: return unbox (v);
    case DV_RDF: return ((rdf_box_t *) v)->rb_ro_id;
    default: return 0;
    }
}


/* knnSimilar over RDF_QUAD.O.  Driving: for each input set, the O of each of the k
   nearest literals.  Check: the input sets whose O is one of them.  Either way the same
   k, so the answer does not depend on which of the two the plan uses. */
static void
vvec_rdf_search_input (vvec_search_node_t * vsn, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  QNCAST (data_source_t, qn, vsn);
  int n_sets, nth_set, pos, batch_sz;
  if (!qn->src_sets)
    {
      caddr_t * cache = vvec_rdf_hits (vsn, inst);
      if (vsn->vsn_is_driving)
	{
	  caddr_t * rows = (caddr_t *) cache[2];
	  for (pos = 0; pos < BOX_ELEMENTS (rows); pos++)
	    {
	      caddr_t * row = (caddr_t *) rows[pos];
	      vvec_rdf_set_o (vsn, inst, unbox (row[0]));
	      vvec_rdf_set_score (vsn, inst, row[1]);
	      qn_send_output (qn, inst);
	    }
	}
      else
	{
	  int64 ro_id = vvec_rdf_in_ro_id (vsn, inst);
	  caddr_t * row = ro_id ? vvec_rdf_find ((caddr_t *) cache[3], ro_id) : NULL;
	  if (row)
	    {
	      vvec_rdf_set_score (vsn, inst, row[1]);
	      qn_send_output (qn, inst);
	    }
	}
      return;
    }
  n_sets = qn->src_prev ? QST_INT (inst, qn->src_prev->src_out_fill) : qi->qi_n_sets;
  if (state)
    {
      QST_INT (inst, vsn->clb.clb_nth_set) = 0;
      qst_set_long (inst, vsn->vsn_pos, 0);
    }
  nth_set = QST_INT (inst, vsn->clb.clb_nth_set);
  pos = (int) unbox (qst_get (inst, vsn->vsn_pos));
  batch_sz = QST_INT (inst, qn->src_batch_size);
  if (batch_sz <= 0)
    batch_sz = dc_batch_sz;
  QST_INT (inst, qn->src_out_fill) = 0;
  dc_reset_array (inst, qn, qn->src_continue_reset, -1);
  for (; nth_set < n_sets; nth_set++, pos = 0)
    {
      caddr_t * cache;
      qi->qi_set = nth_set;
      cache = vvec_rdf_hits (vsn, inst);
      if (vsn->vsn_is_driving)
	{
	  caddr_t * rows = (caddr_t *) cache[2];
	  int n = BOX_ELEMENTS (rows);
	  while (pos < n)
	    {
	      caddr_t * row = (caddr_t *) rows[pos++];
	      vvec_rdf_set_o (vsn, inst, unbox (row[0]));
	      vvec_rdf_set_score (vsn, inst, row[1]);
	      qn_result (qn, inst, nth_set);
	      if (QST_INT (inst, qn->src_out_fill) >= batch_sz)
		{
		  QST_INT (inst, vsn->clb.clb_nth_set) = nth_set;
		  qst_set_long (inst, vsn->vsn_pos, pos);
		  SRC_IN_STATE (qn, inst) = inst;
		  qn_send_output (qn, inst);
		  QST_INT (inst, qn->src_out_fill) = 0;
		  dc_reset_array (inst, qn, qn->src_continue_reset, -1);
		  qi->qi_set = nth_set;
		}
	    }
	}
      else
	{
	  int64 ro_id = vvec_rdf_in_ro_id (vsn, inst);
	  caddr_t * row = ro_id ? vvec_rdf_find ((caddr_t *) cache[3], ro_id) : NULL;
	  if (row)
	    {
	      vvec_rdf_set_score (vsn, inst, row[1]);
	      qn_result (qn, inst, nth_set);
	      if (QST_INT (inst, qn->src_out_fill) >= batch_sz)
		{
		  QST_INT (inst, vsn->clb.clb_nth_set) = nth_set + 1;
		  SRC_IN_STATE (qn, inst) = inst;
		  qn_send_output (qn, inst);
		  QST_INT (inst, qn->src_out_fill) = 0;
		  dc_reset_array (inst, qn, qn->src_continue_reset, -1);
		}
	    }
	}
    }
  SRC_IN_STATE (qn, inst) = NULL;
  if (QST_INT (inst, qn->src_out_fill))
    qn_send_output (qn, inst);
}


void
vvec_search_node_input (vvec_search_node_t * vsn, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  caddr_t *qst = inst;
  caddr_t results;
  int pos;
  int n_rows;
  int batch_sz;

  if (vsn->vsn_rdf)
    {
      vvec_rdf_search_input (vsn, inst, state);
      return;
    }
  if (!state)
    state = qn_get_in_state ((data_source_t *) vsn, inst);
  if (!state || !vsn->vsn_vec_key)
    return;
  results = qst_get (qst, vsn->vsn_results);
  if (!results)
    {
      caddr_t query_vec;
      caddr_t embedded_vec = NULL;
      int k = (int) unbox (QST_GET (qst, vsn->vsn_k));
      int ef_search = (int) unbox (QST_GET (qst, vsn->vsn_ef_search));

      /* Query text is embedded here, once per query execution (this whole
	 block runs exactly once, gated by vsn_results), instead of via a
	 separately-compiled __VEC_INDEX_QUERY_TEXT_VECTOR Precode call whose
	 result then has to be threaded back in via an SSL_REF.  This also
	 sidesteps that BIF's own global, single-slot, mutex-guarded cache
	 (vvec_query_text_vector_*), which serializes and thrashes under any
	 concurrent mix of text-query-vector searches -- this path never
	 touches that cache at all. */
      if (vsn->vsn_query_text)
	{
	  vvec_meta_t meta;
	  char *text_value = (char *) QST_GET (qst, vsn->vsn_query_text);
	  vvec_require_key (qi, "vvec_search_node", vsn->vsn_vec_key->key_name, &meta);
	  if (VVEC_SOURCE_VECTOR == meta.vm_source_kind)
	    sqlr_new_error ("42000", "VEC88",
		"Vector index %.300s has no embedding model (source_kind='vector'); query it by vector with X_SIMILAR (col, <vector>, k), not by text.",
		vsn->vsn_vec_key->key_name);
	  embedded_vec = vvec_embed_text_for_model (qi, "vvec_search_node", vsn->vsn_vec_key->key_name, &meta, text_value);
	  query_vec = embedded_vec;
	}
      else
	query_vec = QST_GET (qst, vsn->vsn_query_vec);

      if (k <= 0)
	k = 10;
      if (ef_search < k)
	ef_search = k;
      results = vvec_search_run_key (qi, "vvec_search_node", vsn->vsn_vec_key, query_vec, k, ef_search);
      if (embedded_vec)
	dk_free_tree (embedded_vec);
      qst_set (qst, vsn->vsn_results, results);
      qst_set_long (qst, vsn->vsn_pos, 0);
    }

  if (!IS_BOX_POINTER (results) || DV_ARRAY_OF_POINTER != DV_TYPE_OF (results))
    {
      qst_set (qst, vsn->vsn_results, NULL);
      qn_record_in_state ((data_source_t *) vsn, inst, NULL);
      return;
    }

  n_rows = BOX_ELEMENTS ((caddr_t *) results);
  pos = (int) unbox (QST_GET (qst, vsn->vsn_pos));
  batch_sz = vsn->src_gen.src_sets && vsn->src_gen.src_batch_size
      ? QST_INT (qst, vsn->src_gen.src_batch_size) : 1;
  if (batch_sz <= 0)
    batch_sz = dc_batch_sz;
  while (pos < n_rows)
    {
	QST_INT (qst, vsn->src_gen.src_out_fill) = 0;
	dc_reset_array (inst, (data_source_t *) vsn, vsn->src_gen.src_continue_reset, -1);
	while (pos < n_rows && QST_INT (qst, vsn->src_gen.src_out_fill) < batch_sz)
	{
	  caddr_t row_box = ((caddr_t *) results)[pos++];
	  qst_set_long (qst, vsn->vsn_pos, pos);
	  if (IS_BOX_POINTER (row_box) && DV_ARRAY_OF_POINTER == DV_TYPE_OF (row_box)
	      && BOX_ELEMENTS ((caddr_t *) row_box) >= 2)
	    {
	      caddr_t *row = (caddr_t *) row_box;
	      VSN_QST_SET (vsn, qst, vsn->vsn_pk_id, box_copy_tree (row[0]));
	      if (vsn->vsn_distance)
		VSN_QST_SET (vsn, qst, vsn->vsn_distance, box_copy_tree (row[1]));
	      if (vsn->vsn_similarity)
		{
		  float row_distance = 0;
		  if (IS_BOX_POINTER (row[1]))
		    {
		      if (DV_DOUBLE_FLOAT == DV_TYPE_OF (row[1]))
			row_distance = (float) unbox_double (row[1]);
		      else if (DV_SINGLE_FLOAT == DV_TYPE_OF (row[1]))
			row_distance = unbox_float (row[1]);
		    }
		  VSN_QST_SET (vsn, qst, vsn->vsn_similarity,
		      box_float (vvec_similarity_from_distance (row_distance, (int) vsn->vsn_metric)));
		}
	      if (vsn->src_gen.src_sets)
		qn_result ((data_source_t *) vsn, qst, 0);
	      else
		QST_INT (qst, vsn->src_gen.src_out_fill) = 1;
	    }
	}
	if (QST_INT (qst, vsn->src_gen.src_out_fill))
	  qn_send_output ((data_source_t *) vsn, inst);
    }

  qst_set (qst, vsn->vsn_results, NULL);
  qn_record_in_state ((data_source_t *) vsn, inst, NULL);
}


void
vvec_search_node_free (vvec_search_node_t * vsn)
{
  /* Nothing to free - vvec_search_node owns no persistent state */
}

#undef VSN_QST_SET


/* M5: BIF to get/set the sqlo_vvec_require_ann session variable.
 * sqlo_vvec_require_ann([new_value]) returns current value.
 * When set to 1, queries using VECTOR_DISTANCE or X_SIMILAR on columns
 * without a vector index will fail at compile time.
 */
static caddr_t
bif_sqlo_vvec_require_ann (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  client_connection_t * cli = qi->qi_client;
  (void) err_ret;
  caddr_t ret = box_num (sqlo_vvec_require_ann_for_client (cli));
  if (BOX_ELEMENTS (args) > 0)
    {
      int new_val = bif_long_arg (qst, args, 0, "sqlo_vvec_require_ann");
      caddr_t name = box_dv_short_string (VVEC_REQUIRE_ANN_CLI_VAR);
      caddr_t val = box_num (new_val ? 1 : 0);
      connection_set (cli, name, val);
      dk_free_box (name);
      dk_free_box (val);
    }
  return ret;
}


/* BIF to get/set the sqlo_vvec_filter_mode session variable.
 * sqlo_vvec_filter_mode([new_value]) returns the current value.
 *   0 = auto (cost-based), 1 = force filter/rerank, 2 = force leading ANN.
 * Lets a session pin the similarity filter-vs-ANN choice -- used by tests to
 * assert each mode deterministically, and by operators to override the cost
 * model for a known workload.
 */
static caddr_t
bif_sqlo_vvec_filter_mode (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  client_connection_t * cli = qi->qi_client;
  (void) err_ret;
  caddr_t ret = box_num (sqlo_vvec_filter_mode_for_client (cli));
  if (BOX_ELEMENTS (args) > 0)
    {
      int new_val = (int) bif_long_arg (qst, args, 0, "sqlo_vvec_filter_mode");
      caddr_t name = box_dv_short_string (VVEC_FILTER_MODE_CLI_VAR);
      caddr_t val;
      if (new_val < VVEC_FILTER_MODE_AUTO || new_val > VVEC_FILTER_MODE_ANN)
	{
	  dk_free_box (name);
	  sqlr_new_error ("22023", "VEC64",
	      "sqlo_vvec_filter_mode expects 0 (auto), 1 (filter) or 2 (ann); got %d.", new_val);
	}
      val = box_num (new_val);
      connection_set (cli, name, val);
      dk_free_box (name);
      dk_free_box (val);
    }
  return ret;
}


/* The distance kernels in use (vvec_simd.h): (family, 1 when the CPU runs the
   AVX2+FMA kernels, the family the build selected at compile time). */
static caddr_t
bif_vec_simd_info (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) err_ret;
  (void) args;
  sec_check_dba ((query_instance_t *) qst, "__VEC_SIMD_INFO");
  return list (3, box_dv_short_string (vvec_simd_family ()), box_num (vvec_simd_cpu_avx2_fma ()),
      box_dv_short_string (VVEC_SIMD_BUILD_FAMILY));
}


/* The six kernels of one family -- 'auto' for the ones in use -- on seeded
   vectors of DIM floats, against a double-precision oracle.  Returns (family,
   worst error, then each kernel's: l2sqr, l1, ip, and the same three reading
   the left vector from its on-page form).  An error is relative to the sum of
   the kernel's terms, so it does not depend on the vectors' scale. */
static caddr_t
bif_vec_simd_selftest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int dim = (int) bif_long_range_arg (qst, args, 0, "__VEC_SIMD_SELFTEST", 1, 65536);
  const char * family = BOX_ELEMENTS (args) > 1 ? bif_string_arg (qst, args, 1, "__VEC_SIMD_SELFTEST") : "auto";
  const vvec_simd_kernels_t * k;
  unsigned int seed = 0x5eed1234u + (unsigned int) dim;
  double l2 = 0, l1 = 0, ip = 0, ipabs = 0, err[6], worst = 0;
  float got[6];
  float * a, * b;
  unsigned char * ae;
  int i;
  caddr_t res;
  (void) err_ret;
  sec_check_dba ((query_instance_t *) qst, "__VEC_SIMD_SELFTEST");
  k = vvec_simd_kernels_by_name (family);
  if (!k)
    {
      const char * more = "";
#if defined(VVEC_SIMD_NEON)
      more = ", neon";
#elif defined(VVEC_SIMD_AVX2)
      if (vvec_simd_cpu_avx2_fma ())
	more = ", avx2";
#endif
      sqlr_new_error ("22023", "VEC49",
	  "__VEC_SIMD_SELFTEST: no distance kernels named '%.100s' on this machine, which has auto, scalar%s",
	  family, more);
    }
  a = (float *) dk_alloc (dim * sizeof (float));
  b = (float *) dk_alloc (dim * sizeof (float));
  ae = (unsigned char *) dk_alloc (dim * 4);
  for (i = 0; i < dim; i++)
    {
      seed = seed * 1103515245u + 12345u;
      a[i] = ((seed >> 8) & 0xffff) / 32768.0f - 1.0f;
      seed = seed * 1103515245u + 12345u;
      b[i] = ((seed >> 8) & 0xffff) / 32768.0f - 1.0f;
      vvec_float_set (ae + 4 * i, a[i]);
      l2 += ((double) a[i] - b[i]) * ((double) a[i] - b[i]);
      l1 += fabs ((double) a[i] - b[i]);
      ip += (double) a[i] * b[i];
      ipabs += fabs ((double) a[i] * b[i]);
    }
  got[0] = k->l2sqr_f32 (a, b, dim);
  got[1] = k->l1_f32 (a, b, dim);
  got[2] = k->ip_f32 (a, b, dim);
  got[3] = k->l2sqr_extf32 (ae, b, dim);
  got[4] = k->l1_extf32 (ae, b, dim);
  got[5] = k->ip_extf32 (ae, b, dim);
  for (i = 0; i < 6; i++)
    {
      double want = (i % 3 == 0) ? l2 : (i % 3 == 1) ? l1 : ip;
      double scale = (i % 3 == 0) ? l2 : (i % 3 == 1) ? l1 : ipabs;
      err[i] = fabs ((double) got[i] - want) / (scale > 1e-30 ? scale : 1e-30);
      if (err[i] > worst)
	worst = err[i];
    }
  dk_free (a, dim * sizeof (float));
  dk_free (b, dim * sizeof (float));
  dk_free (ae, dim * 4);
  res = list (8, box_dv_short_string (k->family), box_double (worst),
      box_double (err[0]), box_double (err[1]), box_double (err[2]),
      box_double (err[3]), box_double (err[4]), box_double (err[5]));
  return res;
}


extern int rb_type__xsd_string;
extern int rb_type__rdf_langString;

/* Ready vector indexes on DB.DBA.RDF_OBJ; gates the RDF_OBJ_VEC_LOG hooks at literal creation. */
int
vvec_rdf_obj_n_indexes (void)
{
  dbe_table_t * tb = wi_inst.wi_schema ? sch_name_to_table (wi_inst.wi_schema, "DB.DBA.RDF_OBJ") : NULL;
  int n = 0;
  if (!tb)
    return 0;
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      if (vvec_key_ready (key)
          && VVEC_SOURCE_RDF_OBJ == vvec_parse_source_kind (vvec_opt_value (key->key_options, VVEC_OPT_SOURCE_KIND)))
	n++;
    }
  END_DO_SET ();
  return n;
}


/* The index knnSimilar searches: NAME, or the only one when NAME is NULL.  *n_ret gets how many there are.
   NAME is the name the index was created under; its key is RDF_OBJ_ and NAME with every
   non-alphanumeric as '_', as DB.DBA.RDF_OBJ_VEC_INDEX_KEY derives it.  An older key without
   the prefix is found by its plain name. */
dbe_key_t *
vvec_rdf_obj_search_key (const char * name, int * n_ret)
{
  dbe_table_t * tb = wi_inst.wi_schema ? sch_name_to_table (wi_inst.wi_schema, "DB.DBA.RDF_OBJ") : NULL;
  dbe_key_t * found = NULL;
  char plain[MAX_NAME_LEN * 3];
  char key_name[MAX_NAME_LEN * 3 + 8];
  int n = 0;
  *n_ret = 0;
  if (!tb)
    return NULL;
  vvec_name_sanitize (plain, sizeof (plain), name);
  snprintf (key_name, sizeof (key_name), "%s%s", strnicmp (plain, "RDF_OBJ_", 8) ? "RDF_OBJ_" : "", plain);
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      if (!vvec_key_ready (key)
          || VVEC_SOURCE_RDF_OBJ != vvec_parse_source_kind (vvec_opt_value (key->key_options, VVEC_OPT_SOURCE_KIND)))
	continue;
      n++;
      if (name ? (!stricmp (key->key_name, key_name) || (!found && !stricmp (key->key_name, plain))) : !found)
	found = key;
    }
  END_DO_SET ();
  *n_ret = n;
  if (!name && n > 1)
    return NULL;
  return found;
}


static caddr_t
bif_vec_rdf_obj_active (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (vvec_rdf_obj_n_indexes ());
}


/* A plain, language-tagged or xsd:string literal, given RO_DT_AND_LANG. */
static caddr_t
bif_vec_rdf_obj_is_string_dt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  boxint dt_and_lang = bif_long_arg (qst, args, 0, "__vec_rdf_obj_is_string_dt");
  int dt = (int) ((dt_and_lang >> 16) & 0xffff);
  return box_num (RDF_BOX_DEFAULT_TYPE == dt || (rb_type__xsd_string && rb_type__xsd_string == dt)
      || (rb_type__rdf_langString && rb_type__rdf_langString == dt));
}


void
bif_vvec_init (void)
{
  static int inited = 0;
  if (inited)
    return;
  inited = 1;
  srand ((unsigned int) time (NULL));
  /* Before anything computes a distance: on x86-64 this picks the AVX2+FMA
     kernels when the CPU runs them. */
  vvec_simd_select ();
  log_info ("Vector index distance kernels: %s", vvec_simd_family ());
  if (!vvec_query_text_vector_mtx)
    vvec_query_text_vector_mtx = mutex_allocate ();
  if (!vvec_health_mtx)
    vvec_health_mtx = mutex_allocate ();
  if (!vvec_health_hash)
    vvec_health_hash = hash_table_allocate (31);
  if (!vvec_arena_hash_mtx)            /* perf phase 2: key_id -> in-memory vector arena */
    vvec_arena_hash_mtx = mutex_allocate ();
  if (!vvec_arena_hash)
    vvec_arena_hash = hash_table_allocate (31);
  if (!vvec_compile_mtx)
    vvec_compile_mtx = mutex_allocate ();
  bif_define_ex ("__VEC_INDEX_INSERT_EMBEDDING", bif_vvec_insert_embedding, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_EMBED_AND_INSERT", bif_vvec_embed_and_insert, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_DELETE_ROW", bif_vvec_delete_row, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_DELETE_EMBEDDING", bif_vvec_delete_embedding, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_DELETE_BATCH", bif_vvec_delete_batch, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_INSERT_TEST_EMBEDDING", bif_vvec_insert_test_embedding, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_TEST_EMBEDDING", bif_vvec_test_embedding, BMD_IS_DBA_ONLY, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_INSERT_BATCH", bif_vvec_insert_batch, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_STAGE_BATCH", bif_vvec_stage_batch, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_SEARCH", bif_vvec_search, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_SEARCH_TEST_EMBEDDING", bif_vvec_search_test_embedding, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__vvec_ann_plan", bif_vvec_ann_plan, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__vvec_page_image_peak", bif_vvec_page_image_peak, BMD_IS_DBA_ONLY, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_METRICS", bif_vvec_metrics, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_VALIDATE", bif_vvec_validate, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_REBUILD", bif_vvec_rebuild, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_HEALTH_RECHECK", bif_vvec_health_recheck, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_PAGE_STATS", bif_vvec_page_stats, BMD_IS_DBA_ONLY, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_ROW_DISTANCE", bif_vvec_row_distance, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_ROW_SIMILARITY", bif_vvec_row_similarity, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__VEC_IDENTITY", bif_vvec_identity, BMD_DONE);
  bif_define_ex ("VVEC_TO_FLOAT_VECTOR", bif_vvec_to_float_vector, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_QUERY_TEXT_VECTOR", bif_vvec_query_text_vector, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__VEC_INDEX_QUERY_TEXT_VECTOR_CALLS", bif_vvec_query_text_vector_calls, BMD_IS_DBA_ONLY, BMD_DONE);

  bif_define_ex ("VECTOR_DISTANCE", bif_vector_distance, BMD_DONE);
  bif_define_ex ("COSINE_DISTANCE", bif_cosine_distance, BMD_DONE);
  bif_define_ex ("DOT_PRODUCT", bif_dot_product, BMD_DONE);
  bif_define_ex ("INNER_PRODUCT", bif_inner_product, BMD_DONE);
  bif_define_ex ("VECTOR_NORM", bif_vector_norm, BMD_DONE);
  bif_define_ex ("VVEC_ADD", bif_vvec_add, BMD_DONE);
  bif_define_ex ("VVEC_SUBTRACT", bif_vvec_subtract, BMD_DONE);
  bif_define_ex ("VVEC_MULTIPLY", bif_vvec_multiply, BMD_DONE);
  bif_define_ex ("VVEC_DIVIDE", bif_vvec_divide, BMD_DONE);
  bif_define_ex ("VVEC_SCALAR_MULTIPLY", bif_vvec_scalar_multiply, BMD_DONE);
  bif_define_ex ("VVEC_SCALAR_DIVIDE", bif_vvec_scalar_divide, BMD_DONE);
  bif_define_ex ("VVEC_NORMALIZE", bif_vvec_normalize, BMD_DONE);
  bif_define_ex ("VVEC_DIMENSION", bif_vvec_dimension, BMD_DONE);
  bif_define_ex ("L1_DISTANCE", bif_l1_distance, BMD_DONE);
  bif_define_ex ("L2_DISTANCE", bif_l2_distance, BMD_DONE);
  bif_define_ex ("X_SIMILAR", bif_x_similar, BMD_DONE);
  bif_define_ex ("__VEC_SIMD_INFO", bif_vec_simd_info, BMD_IS_DBA_ONLY, BMD_MAX_ARGCOUNT, 0, BMD_DONE);
  bif_define_ex ("__VEC_SIMD_SELFTEST", bif_vec_simd_selftest, BMD_IS_DBA_ONLY,
      BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 2, BMD_DONE);
  bif_define_ex ("sqlo_vvec_require_ann", bif_sqlo_vvec_require_ann, BMD_DONE);
  bif_define_ex ("sqlo_vvec_filter_mode", bif_sqlo_vvec_filter_mode, BMD_DONE);
  bif_define_ex ("__vec_rdf_obj_active", bif_vec_rdf_obj_active, BMD_RET_TYPE, &bt_integer, BMD_MAX_ARGCOUNT, 0, BMD_DONE);
  bif_define_ex ("__vec_rdf_obj_is_string_dt", bif_vec_rdf_obj_is_string_dt, BMD_RET_TYPE, &bt_integer,
      BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_DONE);
}
