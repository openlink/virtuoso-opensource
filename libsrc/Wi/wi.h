/*
 *  wi.h
 *
 *  $Id$
 *
 *  Data structures
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2006 OpenLink Software
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


/* Main header file for database engine */

#ifndef _WI_H
#define _WI_H

#define VAJRA
#define O12 GPF_T1("Database engine does not support this deprecated function. Please contact OpenLink Support.")
/*#define PAGE_TRACE 1 */
/* #define DBG_BLOB_PAGES_ACCOUNT */
#undef OLD_HASH
#if !defined (NEW_HASH)
#define NEW_HASH
#endif

#define AUTO_COMPACT

#ifndef bitf_t
#define bitf_t unsigned
#endif

#ifndef REPLICATION_SUPPORT2
#define REPLICATION_SUPPORT2 1
#endif
#ifndef REPLICATION_SUPPORT
#define REPLICATION_SUPPORT 1
#endif
#include "Dk.h"

#undef log

/*
 *  Global features
 */
#ifndef REPLICATION_SUPPORT	/* Support for replication */
# define REPLICATION_SUPPORT	1
# define REPLICATION_SUPPORT2	1
#endif
typedef struct free_set_cache_s	free_set_cache_t;
typedef struct index_tree_s	index_tree_t;
typedef struct search_spec_s	search_spec_t;
typedef struct placeholder_s	placeholder_t;
typedef struct it_cursor_s	it_cursor_t;
typedef struct page_map_s	page_map_t;
typedef struct buffer_desc_s	buffer_desc_t;
typedef struct it_map_s it_map_t;
#if 0
typedef int errcode;
#else
#ifndef _ERRCODE_DEFINED
typedef int errno_t;
#endif
#endif
typedef struct remap_s remap_t;
typedef struct buffer_pool_s buffer_pool_t;
typedef struct hash_index_s hash_index_t;
typedef int (*key_cmp_t) (buffer_desc_t * buf, int pos, it_cursor_t * itc);

#define WI_OK		0
#define WI_ERROR	-1

#include "widisk.h"
#include "widv.h"
#include "numeric.h"
#include "ltrx.h"
#include "widd.h"
#include "blobio.h"
#include "wifn.h"
#include "bitmap.h"

extern int it_n_maps;
#define IT_N_MAPS it_n_maps
#define IT_N_MAPS_MASK (it_n_maps - 1)

struct it_map_s
{
  dk_mutex_t 	itm_mtx;
  dk_hash_t	itm_dp_to_buf;
  dk_hash_t	itm_remap;
  dk_hash_t	itm_locks;
};

#define IT_DP_MAP(it, dp) \
  (&(it)->it_maps[(dp) & IT_N_MAPS_MASK])





#define IT_DP_TO_BUF(it, dp) \
  (buffer_desc_t *) gethash (DP_ADDR2VOID (dp), &IT_DP_MAP ((it), dp)->itm_dp_to_buf)

#define IT_DP_REMAP(it, dp, remap_dp) \
{ \
  it_map_t * itm = IT_DP_MAP (it, dp); \
  remap_dp = (dp_addr_t)(ptrlong) gethash (DP_ADDR2VOID (dp), &itm->itm_remap); \
  if (!remap_dp) \
    remap_dp = (dp_addr_t)(ptrlong) gethash (DP_ADDR2VOID (dp), it->it_storage->dbs_cpt_remap); \
  if (!remap_dp) \
    remap_dp = dp; \
}


#define FC_SLOTS 10


struct free_set_cache_s
  {
    /* caches words of page allocation bitmap where unallocated pages exist */
    dp_addr_t		fc_first_free;
    dp_addr_t		fc_free_around [FC_SLOTS];
    int			fc_replace_next;
  };

typedef unsigned int32 bp_ts_t; /* timestamp of buffer, use in  cache replacement to distinguish old buffers.  Faster than double linked list for LRU.  Wraparound does not matter since only differences of values are considered.  */

#define BP_N_BUCKETS 5

struct buffer_pool_s
{
  /* Buffer cache pool.  Many pools exist to avoid a single critical section for cache replacement */
  buffer_desc_t *	bp_bufs;
  int			bp_n_bufs;
  int			bp_next_replace; /*index into bp_bufs, points where the previous cache replacement took place */
  buffer_desc_t *	bp_first_free; /* when bufs become available through delete, they are pushed here and linked via bd_next */
  dk_mutex_t *	bp_mtx; /* serialize free buffer lookup in this pool */
  bp_ts_t	bp_ts; /* ts to assign to next touched buffer */
  bp_ts_t	bp_stat_ts; /* bp_ts as of when the pool age stats were last computed */

  unsigned char * bp_storage;	/* pointer to storage area */

  /* Each pool is divided into BP_N_BUCKETS, each holding a approx
   * * equal no f buffers.  They are divided by bp_ts, with the 1st bucket
   * holding the oldest 1/BP_N_BUCKETS and so on.  Used for scheduling
   * relatively old dirty buffers for flush to disk.  Each */

  int32		bp_bucket_limit[BP_N_BUCKETS];
  int		bp_n_clean[BP_N_BUCKETS]; /* bp_ts at the boundary between buckets */
  int 		bp_n_dirty[BP_N_BUCKETS];
  buffer_desc_t **	bp_sort_tmp;
};


#define IN_BP(in) \
  mutex_enter (bp->bp_mtx)

#define LEAVE_BP(in) \
  mutex_leave (bp->bp_mtx)


#define wi_schema wi_master_wd->wd_schema
#define wi_master wi_master_wd->wd_primary_dbs


typedef struct wi_inst_s
{
  /* Global data representing a Virtuoso server instance */
  wi_db_t *		wi_master_wd;  /* initial and only logical database */
  dk_set_t 		wi_dbs; /* list of database file groups  */
  uint32			wi_n_dirty; /* dirty buffer count, approx The real count is in the buffer pools.  */
  dk_set_t		wi_free_schemas; /* schema structs awaiting idle moment for safe deallocation */
  int32			wi_max_dirty;
  int			wi_is_checkpoint_pending; /* true if no new activity should be started due to checkpoint */
  dk_set_t		wi_waiting_checkpoint; /* threads suspended for checkpoint duration */

  dk_set_t	wi_storage;
  char *		wi_open_mode; /* various crash recovery options */
  dk_mutex_t *	wi_txn_mtx; /* serialize lock wait graph and transaction thread counts */
  buffer_pool_t **	wi_bps;  /* set of buffer pools */
  short	wi_n_bps;
  unsigned short	wi_bp_ctr; /* round robin buffer pool counter, not serialized, used for picking  a different pool on consecutive buffer replacements */

  dbe_storage_t *	wi_temp;  /* file group for temp db, sort temps, hash indices etc. */
  short			wi_temp_allocation_pct;
  id_hash_t * 		wi_files;
} wi_inst_t;

extern wi_inst_t	wi_inst;
EXE_EXPORT (struct wi_inst_s *, wi_instance_get, (void));


struct wi_db_s
{
  /* Logical database.  Can in principle have nmultiple file groups , although now only one is supported */  caddr_t		wd_qualifier;
  dbe_storage_t *	wd_primary_dbs;
  dk_set_t 		wd_storage;
  dbe_schema_t *	wd_schema;
};


struct dbe_storage_s
{
  /* database file group */
  char		dbs_type;
  caddr_t	dbs_name;
  caddr_t	dbs_cfg_file;
  dk_set_t		dbs_disks; /* list of disk_segment_t for multifile dbs */
  disk_segment_t *	dbs_last_segment;
  dk_set_t 	dbs_trees;
  dk_set_t 	dbs_deleted_trees; /*  dropped indices between now and last checkpoint.  Checkpoint finalizes the drop */

  char *		dbs_file; /* file name if single file dbs. */
  int			dbs_fd;
  OFF_T		dbs_file_length; /* file len if single file. */
  dk_mutex_t *	dbs_file_mtx; /* serializes  dbs_fd, if single file dbs */

  dp_addr_t		dbs_n_pages; /* Total pages in disk array or single file */
  dk_mutex_t *	dbs_page_mtx;  /* serializes page alloc/free */
  du_thread_t *	dbs_owner_thr;  /* thread owning this dbs, also owner of  dbs_page_mtx */
  buffer_desc_t *	dbs_free_set;  /* page allocation bitmap pages */
  buffer_desc_t *	dbs_incbackup_set; /* set of backuped pages for incremental backup */
  free_set_cache_t	dbs_free_cache; /* cache place where free pages last found */
  uint32		dbs_n_free_pages;
  uint32		dbs_n_pages_on_hold;  /* no of pages provisionally reserved for possible delta caused by tree splitting */
  dk_set_t		dbs_cp_remap_pages; /* list of page no's for writing checkpoint remap */
  uint32		dbs_max_cp_remaps;  /* max checkpoint remap */

  dk_session_t *	dbs_log_session;
  OFF_T		dbs_log_length;
  char *		dbs_log_name;
  log_segment_t *	dbs_log_segments; /* if log over several volumes */
  log_segment_t *	dbs_current_log_segment;  /* null if log segments off */

  dp_addr_t		dbs_registry; /* first page of registry */
  dp_addr_t	dbs_pages_changed;	/* bit map of changes since last backup.  Linked list like free set */
  dk_hash_t *	dbs_cpt_remap; /* checkpoint remaps in this storage unit.  Accessed with no mtx since changes only at checkpoint. */
  index_tree_t *	dbs_cpt_tree;  /* dummy tree for use during checkpoint */
  wi_db_t *		dbs_db;
  dp_addr_t		dbs_dp_sort_offset; /* when sorting buffers for flush, offset by this so as not to mix file groups */
  int			dbs_extend; /* size extend increment in pages */
  dk_hash_t *		dbs_unfreeable_dps;
  char * 		dbs_cpt_file_name;
} ;


/* dbs_type */
#define DBS_PRIMARY 0
#define DBS_SECONDARY 1
#define DBS_TEMP 2
#define DBS_RECOVER 3


#define IN_DBS(dbs) \
  if (dbs->dbs_owner_thr != THREAD_CURRENT_THREAD) \
    { \
      mutex_enter (dbs->dbs_page_mtx); \
      dbs->dbs_owner_thr = THREAD_CURRENT_THREAD; \
    }

#define LEAVE_DBS(dbs) \
{ \
  if (THREAD_CURRENT_THREAD != dbs->dbs_owner_thr)  \
    GPF_T1 ("Leaving dbs without owning it"); \
  dbs->dbs_owner_thr = NULL; \
  mutex_leave (dbs->dbs_page_mtx); \
}



typedef struct hi_signature_s
{
  /* hash index signature.  Indicates what cols of what table are the key and dependent parts */
  caddr_t 	hsi_super_key; /* key id of as int box for the key used to fill the hash inx. If key changes, hash inx is invalidated */
  caddr_t	hsi_n_keys; /* n first of hsi_col_ids relevant for lookup */
  oid_t *	hsi_col_ids; /* columns of the source key in the hash inx */
#ifdef NEW_HASH
  caddr_t	hsi_isolation;  /* record isolation because if made with read committed cannot be reused with repeatable read */
#endif
} hi_signature_t;


#ifdef OLD_HASH
typedef struct hash_inx_elt_s
{
  uint32		he_no;
  dp_addr_t		he_page;
  short			he_pos;
  struct hash_inx_elt_s * 	he_next;
} hash_inx_elt_t;
#endif

#ifdef NEW_HASH
typedef struct hash_inx_b_ptr_s
{
  uint32                hibp_no;
  dp_addr_t		hibp_page;
  short			hibp_pos;
} hash_inx_b_ptr_t;
#endif

struct hash_index_s
{
  mem_pool_t *		hi_pool;
  id_hash_t *		hi_memcache;
  int			hi_size;
  int32			hi_count;
#ifdef OLD_HASH
  hash_inx_elt_t **	hi_elements;
#endif
  dk_set_t 	hi_pages;
  int		hi_page_fill;
  index_tree_t *	hi_it;
  dp_addr_t	hi_last_source_dp;
  dp_addr_t 	*hi_buckets;
  dk_hash_t     *hi_source_pages;
  index_tree_t  *hi_source_tree;
  char		hi_lock_mode;
  char		hi_isolation;
};


typedef struct hash_index_cache_s
{
  /* Global cache of all hash join indices. The idex_reee_t's used for storage are a double linked list for LRU */
  id_hash_t *		hic_hashes;  /* hash from hi_signature_t  to index_tree_t */
  dk_hash_t *		hic_col_to_it; /* from member col id to dk_set_t  of hash inx's invalidated if col changes */
  dk_hash_t *		hic_pk_to_it; /* pk key table to dk_set_t of index_tree_t's of dependent hash indices. Invalidate if ins/del */
  dk_mutex_t *		hic_mtx;
  index_tree_t *	hic_first;
  index_tree_t *	hic_last;
} hash_index_cache_t;


extern hash_index_cache_t hash_index_cache;

#define ASSERT_IN_DBS(dbs) \
  ASSERT_IN_MTX (dbs->dbs_page_mtx)


struct index_tree_s
  {
    /* struct for any index tree, hash inx, sort temp or other set of pages that form a unit */
    dbe_storage_t *	it_storage; /* file group used for storage */
    dbe_key_t *		it_key; /* if index, this is the key */
    volatile dp_addr_t	it_root;
    buffer_desc_t * volatile	it_root_image;
    int volatile		it_root_image_version;
    unsigned short		it_root_version_ctr;
    char		it_is_single_page;
    buffer_desc_t *	it_root_buf;
    dk_mutex_t *	it_lock_release_mtx;
    int		it_fragment_no; /* always 0. I If horiz. fragmentation were supported, would be frg no. */
    hash_index_t * 	it_hi; /* Ifhash index */
    dp_addr_t	it_hash_first;
    char		it_shared;
    char		it_hi_isolation; /* if hash index, isolation used for filling this */
    int		it_ref_count; /* if hash inx, count of qi's using this */
    hi_signature_t *	it_hi_signature;
    dk_set_t 		it_waiting_hi_fill; /* if thi is a hash inx being filled, list of threads waiting for the fill to finish */
    index_tree_t *	it_hic_next; /* links for LRU queue of hash indices */
    index_tree_t *	it_hic_prev;
    int			it_hi_reuses; /* if hash inx, count of reuses */
    long		it_last_used;
    it_map_t *		it_maps;
};


/* it_shared */
#define HI_PRIVATE 0
#define HI_OK 1
#define HI_RETRY 2
#define HI_FILL 3
#define HI_OBSOLETE 4


#define IN_TXN \
  mutex_enter (wi_inst.wi_txn_mtx);

#define LEAVE_TXN \
  mutex_leave (wi_inst.wi_txn_mtx)

#define ASSERT_IN_TXN \
  ASSERT_IN_MTX (wi_inst.wi_txn_mtx)

#define ASSERT_OUTSIDE_TXN \
  ASSERT_OUTSIDE_MTX (wi_inst.wi_txn_mtx)

#define IT_PAGE_IN_RANGE(it, x) \
  (((dp_addr_t) x) < it->it_storage->dbs_n_pages)

#define DBS_PAGE_IN_RANGE(dbs, x) \
  (((dp_addr_t) x) < dbs->dbs_n_pages)

#define IN_CPT_1 \
  mutex_enter (checkpoint_mtx)

#define LEAVE_CPT_1 \
  mutex_leave (checkpoint_mtx)

#define IN_CPT(lt) \
  do { \
    if (lt) { \
      IN_TXN; \
      lt_rollback (lt, TRX_CONT); \
      lt_threads_set_inner (lt, 0); \
      LEAVE_TXN; \
    } \
    IN_CPT_1; \
  } while (0)

#define LEAVE_CPT(lt) \
  do { \
       if (lt) { \
         IN_TXN; \
	 lt_threads_set_inner (lt, 1); \
         LEAVE_TXN; \
       } \
       LEAVE_CPT_1; \
     } while (0)

/* inlined comparison funcs */


typedef struct cmp_desc_s
{
    char	cmd_min_op;
  char		cmd_max_op;
  dtp_t		cmd_dtp;
  char		cmd_non_null;
} cmp_desc_t;


typedef struct cmp_func_desc_s
{
  key_cmp_t 	cfd_func;
  cmp_desc_t *	cfd_compares;
} cmp_func_desc_t;

struct search_spec_s
  {
    char		sp_is_boxed; /* always 1, not used */
    char		sp_min_op; /* compare operator for lower bound */
    char		sp_max_op; /* if this is a range match, compare op for upper bound */
    char		sp_is_reverse; /* true if inserting a DESC sorted item */
    short			sp_min;  /* index into itc_search_params */
    short			sp_max; /* ibid */
    search_spec_t *	sp_next;
    dbe_col_loc_t	sp_cl;  /* column on key, if key on page matches key in compilation */
    dbe_column_t *	sp_col; /* col descriptor, use for finding the col if key on page is obsolete */
    struct state_slot_s *sp_min_ssl;  /* state slot for initializing the cursor's  itc_search_params[sp_min] */
    struct state_slot_s *sp_max_ssl;
    collation_t	 *sp_collation;
    char		sp_like_escape;
  };


typedef struct out_map_s
{
  dbe_col_loc_t	om_cl;
  char 		om_is_null;
} out_map_t;


#define OM_NULL 1
#define OM_ROW 2
#define OM_BM_COL 3
    /* flags for page_wait_access, itc_dive_mode  */
#define PA_READ 0 /* code relies on 0 being PA_READ, as per result of memset 0 */
#define PA_WRITE 1


#define ITC_STORAGE(itc) (itc)->itc_space->isp_tree->it_storage


    /* placeholder_t i the common superclass of a placeholder, a bookmark whose position survives index updates, and of the index tree cursor */

#define PLACEHOLDER_MEMBERS \
  bitf_t		itc_type:3;  \
  bitf_t		itc_is_on_row:1; \
  bitf_t		itc_is_registered:1;	\
  char			itc_lock_mode; \
  short			itc_position; \
  volatile dp_addr_t		itc_page; \
  dp_addr_t		itc_owns_page;  /* cache last owned lock */ \
  buffer_desc_t *	itc_buf_registered; \
  it_cursor_t *		itc_next_on_page; \
  index_tree_t *	itc_tree; \
  bitmap_pos_t		itc_bp

#define ITC_PLACEHOLDER_BYTES \
	((int)(ptrlong)(&((it_cursor_t *)0x0)->itc_is_allocated))

/* itc_type */
#define ITC_PLACEHOLDER	0
#define ITC_CURSOR	1

/* itc_search_mode */
#define SM_INSERT	1
#define SM_READ		0
#define SM_READ_EXACT	2
#define SM_TEXT 4
#define SM_INSERT_BEFORE 5
#define SM_INSERT_AFTER 6

struct placeholder_s
  {
    PLACEHOLDER_MEMBERS;
  };


typedef void (*itc_clup_func_t) (it_cursor_t *);

#define MAX_SEARCH_PARAMS TB_MAX_COLS

#define RA_MAX_ROOTS 80

#define SQLO_RATE_NAME "rnd-stat-rate"

typedef enum { RANDOM_SEARCH_OFF = 0, RANDOM_SEARCH_ON = 1, RANDOM_SEARCH_AUTO = 2 ,
RANDOM_SEARCH_COND = 3} random_search_mode;


struct it_cursor_s
  {
    PLACEHOLDER_MEMBERS;

    char			itc_is_allocated; /* true if dk_alloc'd (not automatic struct */
    char		itc_to_reset; /* what level of change took place while itc waited for page buffer */
    char		itc_max_transit_change; /* quit waiting and do not enter the buffer if itc_transit_change >= this */
    char		itc_acquire_lock; /*when wait over want to own it? */
    char 		itc_search_mode; /* unique match or not */
    char		itc_isolation;
    char		itc_has_blob_logged; /*if blob to log, can't drop blob when inlining it until commit */
    char		itc_random_search;
    bitf_t		itc_dive_mode:1;
    bitf_t		itc_at_data_level:1;
    bitf_t		itc_landed:1; /* true if found position on or between leaves, false if in initial descent through the tree */
    bitf_t		itc_desc_order:1; /* true if reading index from end to start */
    bitf_t		itc_no_bitmap:1;  /* ignore bitmap logic if on bitmap inx */
    bitf_t		itc_desc_serial_landed:1; /* if set, failure to get first lock (right above the selected range) resets search */
    bitf_t		itc_desc_serial_reset:1;
    bitf_t		itc_is_vacuum:1;
    short		itc_map_pos; /* index in page content map */
    /* short			itc_pos_on_parent; */ /* when going up to parent from leaf, cache the pos of the leaf pointer if parent oage did not change */
    key_id_t		itc_key_id;
    key_id_t		itc_row_key_id; /* the key_id of teh actual row on which the itc is */

    short			itc_keep_together_pos;
    short		itc_hash_buf_fill;
    short		itc_hash_buf_prev;
    short			itc_search_par_fill;
    short		itc_owned_search_par_fill;
    short			itc_write_waits; /* wait history. Use for debug */
    short			itc_read_waits;

    dp_addr_t		itc_keep_together_dp;  /* pos. of a pre-image row being replaced by a longer after-update image. */
    /* dp_addr_t		itc_parent_page; */
    int			itc_n_pages_on_hold; /* if inserting, amount provisionally reserved for deltas made by tree split */

    it_map_t *		itc_itm1;  /* points to the iot_map_t if this itc holds the it_map_t's itm_mtx */
    it_map_t *		itc_itm2;
    jmp_buf_splice *	itc_fail_context; /* throw when deadlock or other exception inside index operation */

    du_thread_t *	itc_thread;
    it_cursor_t *	itc_next_waiting; /* next itc waiting on same buffer_desc_t's read/write gate */

    lock_trx_t *	itc_ltrx;
    it_cursor_t *	itc_next_on_lock; /* next itc waiting on same lock */
    struct page_lock_s * itc_pl; /*page_lock_t  of the current page */

    dbe_key_t *		itc_insert_key; /* Key n which operation takes place */
    key_spec_t		itc_key_spec; /* search specs used for indexed lookup */
    search_spec_t *	itc_row_specs; /* earch specs for checking  rows where itc_specs match */
    out_map_t *		itc_out_map;  /* one for each out ssl of the itc_ks->ks_out_slots */
    search_spec_t *	itc_bm_col_spec; /* if set, this is the indexable condition on the bitmapped col */

    db_buf_t		itc_row_data; /* pointer in mid page buffer , where the itc's rows data starts */
    dbe_key_t *		itc_row_key;
    placeholder_t *	itc_bm_split_left_side;
    /* hash index */
    buffer_desc_t *	itc_buf; /* cache the buffer when keeping buffer wired down between rows.  Can be done because always read only.  */
    buffer_desc_t * 	itc_hash_buf; /* when filling a hash, the last buffer, constantly wired down, can be because always oen writer */
    struct word_stream_s *	itc_wst; /* for SM_TEXT search mode */
    caddr_t *		itc_out_state;  /* place out cols here. If null copy from itc_in_state */
    struct key_source_s *	itc_ks;

    /* data areas. not cleared at alloc */
    caddr_t		itc_search_params[MAX_SEARCH_PARAMS];
    caddr_t		itc_owned_search_params[MAX_SEARCH_PARAMS];
    char 		itc_search_param_null[MAX_SEARCH_PARAMS];
    short			itc_ra_root_fill;
    int			itc_n_reads;
    int			itc_nth_seq_page; /* in sequential read, nth consecutive page entered.  Use for starting read ahead.  */

    placeholder_t *	itc_bm_split_right_side;
    int			itc_n_lock_escalations; /* no of times row locks escalated to page locks on this read.  Used for claiming page lock as first choice after history of escalating */
    int			itc_root_image_version;
    dp_addr_t		itc_ra_root[RA_MAX_ROOTS];
    buffer_desc_t *	itc_buf_entered; /* this is set to the entered buf when another thread enters this itc into a buf as a reult of of page_leave_inner on that other thread */
    key_spec_t 	itc_bm_inx_spec; /* replaces itc_specs after itc on bm inx has landed. */

    struct {
      int	sample_size;  /* stop random search after this many rows */
      int	n_sample_rows; /* count of rows retrieved in random traversal */
      dk_hash_t *	cols;	/* hash from de_col_t to col_stat_t *for random sample col stats. */
    } itc_st;
  };


#if DEBUG
#define CHECK_OFF_AND_LEN(off,len,key,row_data,cl) \
  if (((off) < 0) || ((len) < 0) || (((off) + (len)) > (short)ROW_MAX_DATA)) \
    { \
      unsigned char buffer[61], *ptr; \
      int i, j; \
      memset (buffer, 0, sizeof (buffer)); \
      j = 3 * (MIN (20, ROW_MAX_DATA - (off))); \
      for (i = 0, ptr = row_data; i < j; i += 3, ptr++) \
	{ \
	  buffer[i] = "0123456789ABCDEF"[(ptr[0] & 0xF0) >> 4]; \
	  buffer[i + 1] = "0123456789ABCDEF"[ptr[0] & 0x0F]; \
	  buffer[i + 2] = ' '; \
	} \
      if (key && key->key_table) \
	log_error("Row layout error: bad column location (setting the data to NULL will fix it): (key:'%s') (table:'%s') (col:'%s') : %s(%d) off=%d len=%d data='%.60s'", \
            key->key_name, key->key_table->tb_name, __get_column_name (cl.cl_col_id, key), \
            __FILE__, __LINE__, \
            (off), (len), buffer ); \
      else \
	log_error("Row layout error: bad column location (setting the data to NULL will fix it): off=%d len=%d data='%.60s'", \
            (off), (len), buffer ); \
      len = 0; \
    }
#else
#define CHECK_OFF_AND_LEN(off,len,key,row_data,cl)
#endif

    /* Set the off and len to be the offset and length of the column cl on the row on which the itc is */

#define ITC_COL(itc, cl, off, len) \
{ \
  len = cl.cl_fixed_len; \
  if (len > 0) \
    { \
      off = cl.cl_pos; \
    } \
  else if (CL_FIRST_VAR == len) \
    { \
      dbe_key_t * key = itc->itc_row_key; \
      off = itc->itc_row_key_id == 0 ? key->key_key_var_start : key->key_row_var_start; \
      len = SHORT_REF (itc->itc_row_data + key->key_length_area) - off; \
    } \
  else \
    { \
len = -len; \
      off = SHORT_REF (itc->itc_row_data + len); \
      len = SHORT_REF (itc->itc_row_data + len + 2) - off; \
    } \
  CHECK_OFF_AND_LEN(off,len,(itc)->itc_row_key,(itc)->itc_row_data,cl); \
}

#define KEY_COL_WITHOUT_CHECK(key, row_data, cl, off, len) \
{ \
  len = cl.cl_fixed_len; \
  if (len > 0) \
    { \
      off = cl.cl_pos; \
   } \
  else if (CL_FIRST_VAR == len) \
    { \
      off = key->key_row_var_start; \
      len = SHORT_REF (row_data + key->key_length_area) - off; \
   } \
  else \
  { \
len = -len; \
      off = SHORT_REF (row_data + len); \
      len = SHORT_REF (row_data + len + 2) - off; \
    } \
}

#define KEY_COL(key, row_data, cl, off, len) \
{ \
  KEY_COL_WITHOUT_CHECK(key,row_data,cl,off,len) \
  CHECK_OFF_AND_LEN(off,len,key,row_data,cl); \
}

#define ITC_NULL_CK(itc, cl) \
  (itc->itc_row_data[cl.cl_null_flag] & cl.cl_null_mask)


#if 0
/* itc_extension_state - not in use */
#define REXT_NO_EXTENSION	0
#define REXT_UNREAD_EXTENSION	1
#define REXT_EXTENSION		2
#endif
/* itc_acquire_lock */
#define ITC_NO_LOCK 0
#define ITC_GET_LOCK 1
#define ITC_LOCK_IF_ON_ROW 2

/* itc_to_reset - unsigned char, order is important */
/* when calling pae_wait_access, the itc_max_transit_change is one of these.
 * If the change during wait is greater than indicated here, the itc does not enter the buffer.
 * For example if the page of the buffer  splits, the itc will not know whether it still wants to enter the buffer and must restart the search.
 * When the wait is over, itc_to_reset is set to reflect what happened during the wait, again one of the below */

#define RWG_WAIT_NO_ENTRY_IF_WAIT 0 /* Just check if buffer available, wait until is but do not go in */
#define RWG_NO_WAIT	1 /* Only go in if immediately available */
#define RWG_WAIT_NO_CHANGE 2
#define RWG_WAIT_DISK	3
#define RWG_WAIT_DATA	4 /* Data change but no split. */
#define RWG_WAIT_KEY	5 /* insert/delete  but no split */
#define RWG_WAIT_SPLIT	6 /* page split or delete */
#define RWG_WAIT_DECOY 7 /* waited for a decoy buffer which was not replaced by a real buffer.  Retry buffer lookup */
#define RWG_WAIT_ANY 8 /* Means get the buffer no matter what changes during read */


#define ITC	it_cursor_t *


#define ASSERT_BUFF_WIRED(it,buf) do { \
  if ((it)->itc_page != (buf)->bd_page) \
    GPF_T1 ("it->itc_page != buf->bd_page"); \
  if ((it)->itc_landed) \
    { \
      if (!(buf)->bd_is_write) \
	GPF_T1 ("Landed search w/o bd_is_write"); \
    } \
  else \
    { \
      if (!(buf)->bd_readers) \
	GPF_T1 ("Non-landed search w/o db_readers"); \
    } \
} while (0)



#define ITC_INIT(itc, isp, trx) \
  memset ((ITC) itc, 0, ((ptrlong) &(itc)->itc_search_params) - ((ptrlong) itc)); \
  itc->itc_type = ITC_CURSOR; \
  itc->itc_ltrx = trx; \
  itc->itc_lock_mode = PL_SHARED; \

#define ITC_START_SEARCH_PARS(it) \
  it->itc_search_par_fill =0, \
  it->itc_owned_search_par_fill =0

#define ITC_SEARCH_PARAM(it, par) \
{ \
  it->itc_search_param_null[it->itc_search_par_fill] = (DV_DB_NULL == DV_TYPE_OF (par)); \
  it->itc_search_params[it->itc_search_par_fill++] =  ((caddr_t) (par)); \
}



#define ITC_SEARCH_PARAM_NULL(it) \
  it->itc_search_param_null[it->itc_search_par_fill++] = 1

/* when cast of search param to column type makes a new box, it is registered with this so that it is freed with the itc */
#define ITC_OWNS_PARAM(it, par) \
  it->itc_owned_search_params[it->itc_owned_search_par_fill++] = par

/* Relation of itc and page mtxs */


#ifdef MTX_DEBUG
#define mtx_assert(a) assert ((a))
#else
#define mtx_assert(a)
#endif


/* this means that if the page to be entered looks like a leaf, the access mode is preferentially exclusive */
#define ADAPTIVE_LAND
/* the convention for transits is to enter the mtx at the lower address first.  This becomes itc->itm1, the other is itc->ittc_itm2 */

#define ITC_IN_TRANSIT(itc, from_dp, to_dp)\
{\
  it_map_t * itm1 = IT_DP_MAP (itc->itc_tree, from_dp);\
  it_map_t * itm2 = IT_DP_MAP (itc->itc_tree, to_dp);\
  if (itm1 == itm2)\
    {\
      if (itc->itc_itm2 || (itc->itc_itm1 && itc->itc_itm1 != itm1)) GPF_T1 ("single map transit tried while other transit in effect"); \
      itc->itc_itm2 = NULL;\
      if (itc->itc_itm1 != itm1) \
        mutex_enter (&itm1->itm_mtx);\
      itc->itc_itm1 = itm1;\
    }\
  else if (itm1 < itm2)\
    {\
      if (itc->itc_itm1 && itc->itc_itm1 != itm1) GPF_T1 ("entering different transit from that in effect"); \
      if (itc->itc_itm2 && itc->itc_itm2 != itm2) GPF_T1 ("entering different transit from that in effect"); \
      if (!itc->itc_itm1) \
	{ \
	  itc->itc_itm1 = itm1;			\
	  itc->itc_itm2 = itm2;			\
	  mutex_enter (&itm1->itm_mtx);		\
	  mutex_enter (&itm2->itm_mtx);		\
	}\
    }					\
  else \
    {\
      if (itc->itc_itm1 && itc->itc_itm1 != itm2) GPF_T1 ("entering different transit from that in effect"); \
      if (itc->itc_itm2 && itc->itc_itm2 != itm1) GPF_T1 ("entering different transit from that in effect"); \
      if (!itc->itc_itm1) \
	{ \
	  itc->itc_itm1 = itm2;			\
	  itc->itc_itm2 = itm1;			\
	  mutex_enter (&itm2->itm_mtx);		\
	  mutex_enter (&itm1->itm_mtx);		\
	} \
    }\
\
}


#define ITC_ASSERT_TRANSIT(itc, dp1, dp2) \\
{\
  it_map_t itm1 = IT_DP_MAP (itc->itc_tree, dp1);\
  it_map_t itm2 = IT_DP_MAP (itc->itc_tree, dp2);\
  if (itm1 == itm2)\
    {\
      ASSERT_IN_MTX (&itm1->itm_mtx);\
      mtx_assert (itc->itc_itm1 == itm1\
	      && itc->itc_itm2 == NULL);\
    }\
  else\
    {\
      ASSERT_IN_MTX (&itm1->itm_mtx);\
      ASSERT_IN_MTX (&itm2->itm_mtx);\
      mtx_assert ((itc->itc_itm1 == itm1 && itc->itc_itm2 == itm2)\
	      || (itc->itc_itm1 == itm2 && itc->itc_itm2 == itm1));\
    }\
}


#define IT_ASSERT_TRANSIT(it, dp1, dp2) \
{\
  it_map_t * itm1 = IT_DP_MAP (it, dp1);\
  it_map_t * itm2 = IT_DP_MAP (it, dp2);\
  if (itm1 == itm2)\
    {\
      ASSERT_IN_MTX (&itm1->itm_mtx);\
    }\
  else\
    {\
      ASSERT_IN_MTX (&itm1->itm_mtx);\
      ASSERT_IN_MTX (&itm2->itm_mtx);\
    }\
}


#define ITC_LEAVE_MAPS(itc)\
{\
  if (itc->itc_itm1)\
    {\
      mutex_leave (&itc->itc_itm1->itm_mtx);\
      itc->itc_itm1 = NULL;\
    }\
  if (itc->itc_itm2)\
    {\
      mutex_leave (&itc->itc_itm2->itm_mtx);\
      itc->itc_itm2 = NULL;\
    }\
}


#define ITC_LEAVE_MAP_NC(itc) \
{ \
  mtx_assert (itc->itc_itm1 && !itc->itc_itm2); \
  mutex_leave (&itc->itc_itm1->itm_mtx); \
  itc->itc_itm1 = NULL; \
}


#define ASSERT_IN_MAP(it, dp) \
{\
  ASSERT_IN_MTX (&IT_DP_MAP (it, dp)->itm_mtx);	\
}


#define ASSERT_OUTSIDE_MAP(it, dp) \
  ASSERT_OUTSIDE_MTX (&IT_DP_MAP (it, dp)->itm_mtx)

#define ASSERT_OUTSIDE_MAPS(itc)\
  mtx_assert (!itc->itc_itm1 && !itc->itc_itm2)	\


#define ITC_IN_VOLATILE_MAP(itc, dp)\
{\
  ASSERT_OUTSIDE_MAPS (itc);\
  for (;;)\
    {\
      dp_addr_t __to = dp;\
      it_map_t * itm = IT_DP_MAP (itc->itc_tree, __to);\
      mutex_enter (&itm->itm_mtx);\
      if (__to == dp)\
	{\
	  itc->itc_itm1 = itm;\
	  break;\
	}\
      mutex_leave (&itm->itm_mtx);\
      TC (tc_dp_changed_while_waiting_mtx);\
    }\
}\


#define IN_VOLATILE_MAP(it, dp)\
{\
  for (;;)\
    {\
      dp_addr_t __to = dp;\
      it_map_t * itm = IT_DP_MAP (it, __to);\
      mutex_enter (&itm->itm_mtx);\
      if (__to == dp)\
	{\
	  break;\
	}\
      mutex_leave (&itm->itm_mtx);\
      TC (tc_dp_changed_while_waiting_mtx);\
    }\
}\





#define ITC_IN_KNOWN_MAP(itc, dp)\
{\
  it_map_t * itm = IT_DP_MAP (itc->itc_tree, dp);\
  mtx_assert (!itc->itc_itm2); \
  mtx_assert (!itc->itc_itm1 || itc->itc_itm1 == itm);	\
  if (!itc->itc_itm1) \
    mutex_enter (&itm->itm_mtx);\
  itc->itc_itm1 = itm;\
}


#define ITC_IN_OWN_MAP(itc) ITC_IN_KNOWN_MAP ((itc), (itc)->itc_page)


/* Page Content Map */

#define PM_MAX_ENTRIES	 (PAGE_DATA_SZ / 8)


struct page_map_s
  {
    /* For a buffer with index tree content, this struct  holds the starting positions of all entries in index order plus avail. space */
    short	pm_size; /* number of entries actually in pm_entries.  Different sizes of map are allocated for different buffers since having a page full of minimum length entries is very rare */
    short		pm_count;  /* count of rows. This many first entries in pm_entries are valid */
    short		pm_filled_to; /* First free byte of the page's trailing contiguous free space */
    short		pm_bytes_free; /* count of free bytes, including gaps.  If a row of this or less size is inserted, it will fit, maybe needing page compaction */
    short		pm_entries[PM_MAX_ENTRIES]; /* the start offsets of the index entries  on the page */
  };


#define PM_ENTRIES_OFFSET ((int) (ptrlong) &((page_map_t *)0)->pm_entries)


/* the different standard sizes of page_map_t */
#define PM_SZ_1 50
#define PM_SZ_2 100
#define PM_SZ_3 400
#define PM_SZ_4 1021


#define PM_SIZE(ct) \
  (ct < PM_SZ_1 ? PM_SZ_1 : (ct < PM_SZ_2 ? PM_SZ_2 : (ct < PM_SZ_3 ? PM_SZ_3 : PM_SZ_4)))
extern resource_t * pm_rc_1;
extern resource_t * pm_rc_2;
extern resource_t * pm_rc_3;
extern resource_t * pm_rc_4;

#define PM_RC(sz) (sz == PM_SZ_1 ? pm_rc_1 : (sz == PM_SZ_2 ? pm_rc_2 : (sz == PM_SZ_3 ? pm_rc_3 : (sz == PM_SZ_4 ? pm_rc_4 : (resource_t *)(GPF_T1("not a valid pm size"), NULL)))))




#define ROW_LENGTH(row, key, len) \
{ \
  key_id_t key_id = SHORT_REF (row + IE_KEY_ID); \
  if (!key_id) \
    { \
      len = key->key_key_len; \
      if (len <= 0) \
	len = IE_LEAF + 4 + SHORT_REF ((row - len) + IE_LP_FIRST_KEY); \
    } \
  else if (key_id == KI_LEFT_DUMMY) \
    { \
      len = 8; \
    } \
  else \
    { \
      dbe_key_t * row_key; \
      if (key_id != key->key_id) \
	row_key = sch_id_to_key (wi_inst.wi_schema, key_id);  \
      else \
	row_key = key; \
      if (!row_key) STRUCTURE_FAULT; \
      len = row_key->key_row_len; \
      if (len <= 0) \
	len = IE_FIRST_KEY + SHORT_REF ((row - len) + IE_FIRST_KEY); \
    } \
}



#define ITC_REAL_ROW_KEY(itc) \
{ \
  key_id_t key_id = itc->itc_row_key_id; \
  if (key_id) \
    { \
      if (itc->itc_row_key->key_id != key_id) \
	{ \
	  if (key_id == itc->itc_insert_key->key_id) \
	    itc->itc_row_key = itc->itc_insert_key; \
	      else \
	  itc->itc_row_key = sch_id_to_key (wi_inst.wi_schema, key_id); \
	} \
    } \
}


/*#define BUF_DEBUG*/
#define buf_dbg_printf(a) /*printf a*/

#define bd_readers bdf.r.readers
#define bd_is_write bdf.r.is_write
#define bd_being_read bdf.r.being_read
#define bd_is_dirty bdf.r.is_dirty
#define bd_is_ro_cache bdf.r.is_ro_cache

struct buffer_desc_s
{
  /* Descriptor of a page buffer.  Read/write gate and other fields */
  union {
    int32	flags; /* allow testing for all 0's with a single compare.  All zeros mens candidate for reuse. */
    struct {
      short readers; /* count of threads with read access */
      bitf_t	is_write:1;  /* if any thread the exclusive owner of this */
      bitf_t	being_read:1; /* is the buffer allocated for a page and awaiting the data coming from disk */
      bitf_t	is_dirty:1; /* Content changed since last written to disk */
      bitf_t			is_ro_cache;
    } r;
  } bdf;
  bp_ts_t		bd_timestamp; /* Timestamp for estimating age for buffer reuse */
  dp_addr_t		bd_page; /* The logical page number */
  dp_addr_t		bd_physical_page; /* The physical page number, can be different from bd_page if remapped */

  it_cursor_t *	bd_read_waiting;  /* list of cursors waiting for read access */
  it_cursor_t *	bd_write_waiting; /* itc waiting for write access */

  db_buf_t		bd_buffer; /* the 8K bytes for the page */

  union {
    buffer_desc_t *	next; /* Link to next if this is in free set or inc backup set.  If regular buffer, this is a link to the next unused if this buffer is unused, else null */
    it_cursor_t *	registered;
  } bn;
  buffer_pool_t *	bd_pool;
  page_map_t *	bd_content_map; /* only if content is an index page */
  index_tree_t *	bd_tree; /* when caching a page, this is  the index tree  to which the page belongs */
  dbe_storage_t * 	bd_storage; /* the storage unit for reading/writing the page */
  page_lock_t *	bd_pl; /* if lock associated, it's cached here in addition to the tree's hash */
  io_queue_t *	 bd_iq; /* iq, if buffer in queue for read(write */
  buffer_desc_t *	bd_iq_prev; /* next and prev in double linked list of io queue */
  buffer_desc_t *	bd_iq_next;
  int			bd_age;
#ifdef MTX_DEBUG
  du_thread_t *	bd_writer; /* for debugging, the thread which has write access, if any */
  char * 		bd_enter_file;
  long 			bd_enter_line;
  char * 		bd_leave_file;
  long 			bd_leave_line;
  char 			bd_el_flag;	/* what operation was last: 1-enter, 2-leave */
  char *                bd_set_wr_file;
  long                  bd_set_wr_line;
#endif
#ifdef PAGE_TRACE
  long		bd_trx_no;
#endif
#ifdef BUF_DEBUG
  index_tree_t *	bd_prev_tree;
#endif
};

#ifdef MTX_DEBUG
#define BUF_DBG_ENTER(buf) \
    do { \
      if (buf) { \
	(buf)->bd_enter_file = file; \
	(buf)->bd_enter_line = line; \
	(buf)->bd_el_flag = 1; \
      } \
    } while (0)
#define BUF_DBG_LEAVE(buf) \
    do { \
      if (buf) { \
	(buf)->bd_leave_file = file; \
	(buf)->bd_leave_line = line; \
	(buf)->bd_el_flag = 2; \
      } \
    } while (0)
#else
#define BUF_DBG_ENTER(buf)
#define BUF_DBG_LEAVE(buf)
#endif

#define bd_registered bn.registered
#define bd_next bn.next
#define BUF_AGE(buf) (buf->bd_pool->bp_ts - buf->bd_timestamp)

/* mark as recently used */
#define BUF_TOUCH(buf) \
{ \
  (buf)->bd_timestamp = (buf)->bd_pool->bp_ts;		\
  if ((bp_hit_ctr++ & 0x1f) == 0)			\
    (buf)->bd_pool->bp_ts++;				\
}


#define BUF_TICK(buf) buf->bd_pool->bp_ts++;

#define BUF_NONE_WAITING(buf) \
(!buf->bd_write_waiting && !buf->bd_read_waiting && !buf->bd_being_read)

#ifdef MTX_DEBUG
#define BD_SET_IS_WRITE(bd, f) \
{ \
  (bd)->bd_is_write = f;			    \
  (bd)->bd_writer = f ? THREAD_CURRENT_THREAD : NULL;	\
  (bd)->bd_set_wr_file = __FILE__; \
  (bd)->bd_set_wr_line = __LINE__; \
}
#else
#define BD_SET_IS_WRITE(bd, f) \
  (bd)->bd_is_write = f

#endif

struct io_queue_s
  {
    /* io queue.  One should exist for each independently addressable device.
     * Used for ascending order background flush and read ahead of buffers */
    caddr_t		iq_id;
    buffer_desc_t *	iq_first; /* firstof the double linked list of buffers in the queue. */
    buffer_desc_t *	iq_last;
    buffer_desc_t *	iq_current;
    semaphore_t *		iq_sem; /* the io server thread waits on this between batches of pages to be read(written */
    dk_mutex_t * 	iq_mtx; /* serializes access to the buffers list */
    dk_set_t	iq_waiting_shut; /* list of threads waiting for all activity on this iq to finish */
    int		iq_action_ctr; /* if a thread waits for sync, release ity anyway after so many increments of this &*/
  };


#define IN_IOQ(iq) \
  mutex_enter (iq->iq_mtx);

#define LEAVE_IOQ(iq) \
  mutex_leave (iq->iq_mtx);


struct remap_s
  {
    dp_addr_t rm_logical;
    dp_addr_t rm_physical;
  };


#define RA_MAX_BATCH 1000
#define RA_FREE_TEXT_BATCH 20

typedef struct ra_req_s
  {
    int		 ra_inx;
    int			ra_fill;
    int			ra_bfill;
    dp_addr_t		ra_dp[RA_MAX_BATCH];
    buffer_desc_t *	ra_bufs[RA_MAX_BATCH];
    int			ra_nsiblings;
  } ra_req_t;


#ifdef MTX_DEBUG
#define BUF_NEEDS_DELTA(b) 1
#else
#define BUF_NEEDS_DELTA(b) (!(b)->bd_is_dirty)
#endif

#define BUF_WIRED(buf) \
  (buf->bd_readers || buf->bd_is_write \
   || buf->bd_being_read \
   || buf->bd_read_waiting || buf->bd_write_waiting)

#if defined (WIN32)
#define BUF_AVAIL(buf) \
  (buf->bd_readers == 0 \
   && buf->bd_is_write == 0 \
   && buf->bd_being_read == 0 \
   && buf->bd_is_dirty == 0  \
   && !buf->bd_read_waiting && !buf->bd_write_waiting)
#else
#define BUF_AVAIL(buf) \
  (buf->bdf.flags == 0\
   && !buf->bd_read_waiting && !buf->bd_write_waiting)
#endif


#define BUF_CANCEL_WRITE(buf) \
  buf_cancel_write (buf)


/* comparison */

/* for cmp <, <= ==, >, >= the test & 15 is true. For all else test & 15 == 0*/
#define DVC_MATCH 1
#define DVC_LESS 2
#define DVC_GREATER 4
#define DVC_DTP_LESS (2 | DVC_NOORDER)
#define DVC_DTP_GREATER	(4 | DVC_NOORDER)
#define DVC_NOORDER 8
#define DVC_INDEX_END 16
#define DVC_CMP_MASK 15 /* or of bits for eq, lt, gt */
#define DVC_UNKNOWN	64  /* comparison of SQL NULL */
#define DVC_INVERSE(res) ((res) == DVC_LESS ? DVC_GREATER : ((res) == DVC_GREATER ? DVC_LESS : (res)))

/* Comparison operator codes for search_spec_t, sp_min_op, sp_max_op */
#define CMP_NONE 0
#define CMP_EQ 1
#define CMP_LT 2
#define CMP_LTE 3
#define CMP_GT 4
#define CMP_GTE 5
#define CMP_NEQ 14
#define CMP_LIKE 16
#define CMP_NULL 32
#define CMP_NON_NULL 48


#define NUM_COMPARE(n1,n2) \
  (n1 < n2 ? DVC_LESS : (n1 == n2 ? DVC_MATCH : DVC_GREATER))

#define IS_NUM_DTP(dtp) \
  (DV_LONG_INT == dtp || \
   DV_SHORT_INT == dtp || \
   DV_SINGLE_FLOAT == dtp || \
   DV_DOUBLE_FLOAT == dtp || \
   DV_NUMERIC == dtp \
  || DV_INT64 == dtp)

#ifndef dbg_printf
# ifdef DEBUG
#  define dbg_printf(a) { printf a; fflush (stdout); }
# else
#  define dbg_printf(a)
# endif
#endif


/* Catchers */

#define QR_RESET_CTX_T(thr) \
{ \
  du_thread_t * __self = thr; \
  int reset_code;  \
  jmp_buf_splice * __old_ctx = __self->thr_reset_ctx;\
  jmp_buf_splice __ctx;  \
  __self->thr_reset_ctx = &__ctx; \
  if (0 == (reset_code = setjmp_splice (&__ctx)))

#define QR_RESET_CTX  QR_RESET_CTX_T (THREAD_CURRENT_THREAD)

#define QR_RESET_CODE \
  else


#define END_QR_RESET \
    POP_QR_RESET; \
}

#define POP_QR_RESET \
  __self->thr_reset_ctx = __old_ctx




/* Reset  codes */

#define RST_ERROR	1
#define RST_ENOUGH	2 /* for a cursor, reached the end of the current batch of next rows */
#define RST_KILLED	3
#define RST_DEADLOCK	4
#define RST_TIMEOUT	5
#define RST_AT_END 6 /*  reached top or max rows in a select */


#ifdef DEBUG
# define FAILCK(it) if (! it -> itc_fail_context) GPF_T1("No fail context.");
#else
# define FAILCK(it)
#endif

# define ALLOC_CK(xx) dk_alloc_assert ((xx));
#ifdef MALLOC_DEBUG
# define ITC_ALLOC_CK(xx) if ((xx) -> itc_is_allocated) dk_alloc_assert ((xx));
#else
# define ITC_ALLOC_CK(xx) ;
#endif


#define CHECK_SESSION_DEAD(lt) \
{ \
  if (lt) \
    { \
      client_connection_t * cli = lt->lt_client; \
      if (cli->cli_session && cli->cli_session->dks_to_close) \
   { \
       LT_ERROR_DETAIL_SET (lt, \
	   box_dv_short_string ("Client session disconnected")); \
       (lt)->lt_error = LTE_SQL_ERROR; \
       (lt)->lt_status = LT_BLOWN_OFF; \
     } \
    } \
}


/* When inside an itc reset context, periodically call this  to check that no external async condition forces the search to abort or pause */
#define CHECK_TRX_DEAD(it, buf, may_ret) \
{ \
  lock_trx_t *__lt = it->itc_ltrx; \
      CHECK_DK_MEM_RESERVE (__lt); \
      CHECK_SESSION_DEAD (__lt); \
      if ((__lt && __lt->lt_status != LT_PENDING)  \
|| (wi_inst.wi_is_checkpoint_pending && cpt_is_global_lock ())) \
	itc_bust_this_trx (it, buf, may_ret); \
}


/* reset catch context around itc operations */
#define ITC_FAIL(it) \
{   \
  jmp_buf_splice failctx; \
  it->itc_thread = NULL; \
  it->itc_fail_context = &failctx; \
  if (0 == setjmp_splice (&failctx)) \
    {

#define ITC_FAILED \
  } else {

#define END_FAIL_THR(itc, thr) \
    longjmp_splice (thr->thr_reset_ctx, RST_DEADLOCK); \
  } \
  ITC_ALLOC_CK (itc); \
  (itc)->itc_fail_context = NULL; \
}

#define END_FAIL(itc) \
  END_FAIL_THR (itc, THREAD_CURRENT_THREAD)

#define ITC_ABORT_FAIL_CTX(itc) \
  itc->itc_fail_context = NULL

#define ITC_SAVE_FAIL(itc) \
{						    \
  jmp_buf_splice * _s = itc->itc_fail_context;   \

#define ITC_RESTORE_FAIL(itc) \
  itc->itc_fail_context = _s;	 \
  }


#define ITC_CHECK_FAIL(it) \
if (it->itc_ltrx && \
    it->itc_ltrx->lt_blown_off) \
  { \
    if (it->itc_fail_context) \
      longjmp_splice (it->itc_fail_context, RST_DEADLOCK); \
    else \
      GPF_T; \
  } else {};

/* When going to wait for a lock */
#define ITC_SEM_WAIT(it) \
{ \
  mtx_assert (it->itc_thread == THREAD_CURRENT_THREAD);	\
  ITC_LEAVE_MAPS (it); \
  itc_flush_client (it); \
  semaphore_enter (it->itc_thread->thr_sem); \
}


extern jmp_buf_splice structure_fault_ctx;
extern int assertion_on_read_fail;

#define STRUCTURE_FAULT \
{ \
  if (assertion_on_read_fail) \
    GPF_T1 ("Structure fault. Crash recovery recommended."); \
  else \
    longjmp_splice (&structure_fault_ctx, 1); \
}

extern char *run_as_os_uname;
extern long dbe_auto_sql_stats; /* from search.c */

extern int in_crash_dump;

#if defined (WITH_PTHREADS) && !defined (MTX_DEBUG) && !defined (MTX_METER)
#undef mutex_enter
#undef mutex_leave
#define mutex_enter(m)  pthread_mutex_lock (&((m)->mtx_mtx))
#define mutex_leave(m)  pthread_mutex_unlock (&((m)->mtx_mtx))
#endif

#endif /* _WI_H */

