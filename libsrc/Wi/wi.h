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
 *  Copyright (C) 1998-2013 OpenLink Software
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
#define VEC
#define NO_CL GPF_T1 ("not available without cluster support")
#define KEYCOMP GPF_T1 ("not done with key comp");
#define O12 GPF_T1("Database engine does not support this deprecated function. Please contact OpenLink Support.")
/*#define PAGE_TRACE 1 */
/*#define BUF_BOUNDS*/
/* #define DBG_BLOB_PAGES_ACCOUNT */
#undef OLD_HASH
#if !defined (NEW_HASH)
#define NEW_HASH
#endif

#define AUTO_COMPACT

#ifndef bitf_t
#define bitf_t unsigned
#endif

#include "Dk.h"

#undef log

/*
 *  Global features
 */
typedef struct free_set_cache_s	free_set_cache_t;
typedef struct index_tree_s	index_tree_t;
typedef struct search_spec_s	search_spec_t;
typedef struct placeholder_s	placeholder_t;
typedef struct it_cursor_s	it_cursor_t;
typedef struct page_map_s	page_map_t;
typedef struct extent_map_s extent_map_t;
typedef struct buffer_desc_s	buffer_desc_t;
typedef struct it_map_s it_map_t;
#if 0
typedef int errcode;
#else
#ifndef _ERRCODE_DEFINED
typedef int errno_t;
#endif
#endif

#ifdef LARGE_QI_INST
#define MAX_STATE_SLOTS 0xffffe
#else
#define MAX_STATE_SLOTS 0xfffe
#endif
#define STATE_SLOT_LIMIT (MAX_STATE_SLOTS-500)

typedef struct remap_s remap_t;
typedef struct buffer_pool_s buffer_pool_t;
typedef struct hash_index_s hash_index_t;
typedef struct row_delta_s row_delta_t;
typedef struct row_fill_s  row_fill_t;
typedef struct page_fill_s  page_fill_t;
typedef int (*key_cmp_t) (buffer_desc_t * buf, int pos, it_cursor_t * itc);
typedef struct pf_hash_s pf_hash_t;
typedef struct state_slot_s state_slot_t;
typedef struct state_slot_ref_s state_slot_ref_t;
#if (MAX_STATE_SLOTS > 0xffff)
typedef unsigned int ssl_index_t;
#else
typedef unsigned short ssl_index_t;
#endif
typedef struct key_source_s key_source_t;
typedef unsigned short row_no_t;
typedef struct data_col_s data_col_t;
typedef int ce_pos_t;
typedef struct  row_range_s row_range_t;
typedef struct ext_ref_s ext_ref_t;

#define WI_OK		0
#define WI_ERROR	-1

#include "widisk.h"
#include "widv.h"
#include "numeric.h"
#include "widd.h"
#include "ltrx.h"
#include "blobio.h"
#include "wifn.h"
#include "bitmap.h"
#include "extent.h"
#include "col.h"
#include "vec.h"


#define IT_DP_MAP(it, dp) \
  (&(it)->it_maps[(dp) & IT_N_MAPS_MASK])

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
  bp_ts_t	bp_last_buf_ts;
  bp_ts_t	bp_stat_ts; /* bp_ts as of when the pool age stats were last computed */
  char		bp_stat_pending; /* flag for autocompact/stats gathering in progress */

  //unsigned char * bp_storage;	/* pointer to storage area */

  /* Each pool is divided into BP_N_BUCKETS, each holding approximately
   * equal no of buffers. They are divided by bp_ts(bd_timestamp?), with the 1st bucket
   * holding the oldest 1/BP_N_BUCKETS and so on.  Used for scheduling
   * relatively old dirty buffers for flush to disk. */

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
  char			wi_is_checkpoint_pending; /* true if no new activity should be started due to checkpoint */
  char			wi_atomic_ignore_2pc; /* do not wait for prepared uncommitted to be finished  before atomic.  Need that when resetting cluster cfg after node failures */
  char			wi_checkpoint_atomic;
  char			wi_checkpoint_rollback; /* use special cpt delta space for rb results? */
  lock_trx_t *		wi_cpt_lt; /* used to keep stuff rolled back for cpt duration */
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
  char			wi_log_replay_dt[DT_LENGTH]; /* dt of last replayed log time record */
} wi_inst_t;


/* wi_is_checkpoint_pending */
#define CPT_NONE 0
#define CPT_CHECKPOINT 1
#define CPT_ATOMIC_PENDING 2 /* in the process of killing transactions before entering into atomic mode */
#define CPT_ATOMIC 3 /* in atomic mode, only one transaction allowed */


extern wi_inst_t	wi_inst;
EXE_EXPORT (struct wi_inst_s *, wi_instance_get, (void));


struct wi_db_s
{
  /* Logical database. Can in principle have multiple file groups, although now only one is supported */
  caddr_t		wd_qualifier;
  dbe_storage_t *	wd_primary_dbs;
  dk_set_t 		wd_storage;
  dbe_schema_t *	wd_schema;
};


typedef unsigned short ext_ts_t;

#define DBS_EC_N_SETS 8


struct ext_ref_s
{
  /* Reference to a disk extent pending read/write. Extent must not migrate while refd */
  char		er_is_write;
  char		er_is_cache;
  dp_addr_t 	er_ext;
  struct ext_ref_s *	er_next_waiting;
};

#define FILEN_BUFSIZ		256


typedef struct ol_backup_ctx_s
{
  char		db_bp_prfx[FILEN_BUFSIZ];
  dp_addr_t	db_bp_ts;
  dp_addr_t	db_bp_num;
  dp_addr_t	db_bp_pages;
  dp_addr_t	db_bp_date;
  dp_addr_t	db_bp_index;
  dp_addr_t	db_bp_wr_bytes;
} ol_backup_ctx_t;


struct dbe_storage_s
{
  /* database file group */
  char		dbs_type;
  slice_id_t	dbs_slice;
  short		dbs_nth_replica;
  int		dbs_stripe_unit;
  caddr_t	dbs_name;
  caddr_t	dbs_cfg_file;
  dk_set_t		dbs_disks; /* list of disk_segment_t for multifile dbs */
  disk_segment_t *	dbs_last_segment;
  dbe_storage_t **	dbs_slices; /* indexed by dbs_slice, up to highest slid on this host */
  dk_set_t 	dbs_trees;
  dk_set_t 	dbs_deleted_trees; /*  dropped indices between now and last checkpoint.  Checkpoint finalizes the drop */
  dk_set_t	dbs_deleted_ems; /*ibid for column extent maps */
  char *		dbs_file; /* file name if single file dbs. */
  int			dbs_fd;
  OFF_T		dbs_file_length; /* file len if single file. */
  dk_mutex_t *	dbs_file_mtx; /* serializes  dbs_fd, if single file dbs */

  dp_addr_t		dbs_n_pages; /* Total pages in disk array or single file */
  dk_mutex_t *	dbs_page_mtx;  /* serializes page alloc/free */
  du_thread_t *	dbs_owner_thr;  /* thread owning this dbs, also owner of  dbs_page_mtx */
  buffer_desc_t *	dbs_free_set;  /* page allocation bitmap pages */
  buffer_desc_t **	dbs_free_set_arr;
  buffer_desc_t *	dbs_incbackup_set; /* set of backuped pages for incremental backup */
  dp_addr_t		dbs_n_pages_in_sets; /* space for so many bits in free set and backup set */
  uint32		dbs_n_free_pages;
  uint32		dbs_n_pages_on_hold;  /* no of pages provisionally reserved for possible delta caused by tree splitting */
  dk_set_t		dbs_cp_remap_pages; /* list of page no's for writing checkpoint remap */
  uint32		dbs_max_cp_remaps;  /* max checkpoint remap */

  dk_session_t *	dbs_log_session;
  OFF_T		dbs_log_length;
  char *		dbs_log_name;
  log_segment_t *	dbs_log_segments; /* if log over several volumes */
  log_segment_t *	dbs_current_log_segment;  /* null if log segments off */
  dk_session_t *	dbs_2pc_log_session;
  caddr_t		dbs_2pc_file_name;
  id_hash_t *		dbs_registry_hash; /* em start dp's and treeroots here if many dbs's */
  dp_addr_t		dbs_registry; /* first page of registry */
  dp_addr_t	dbs_pages_changed;	/* bit map of changes since last backup.  Linked list like free set */
  dk_hash_t *	dbs_dp_compact_checked;
  dk_hash_t *	dbs_cpt_remap; /* checkpoint remaps in this storage unit.  Accessed with no mtx since changes only at checkpoint. */
  index_tree_t *	dbs_cpt_tree;  /* dummy tree for use during checkpoint */
  wi_db_t *		dbs_db;
  dp_addr_t		dbs_dp_sort_offset; /* when sorting buffers for flush, offset by this so as not to mix file groups */
  int			dbs_extend; /* size extend increment in pages */
  dk_hash_t *		dbs_unfreeable_dps;
  dk_hash_t *		dbs_uc_blob_dps;
  char * 		dbs_cpt_file_name;
  dk_session_t *	dbs_cpt_recov_ses; /* during cpt recov write or recov, the file ses with recov data */
  extent_map_t *	dbs_extent_map; /* system shared general purpose disk extents, housekeeping and small tables */
  dk_hash_t *	dbs_dp_to_extent_map;
  buffer_desc_t *	dbs_extent_set;
  dp_addr_t		dbs_n_pages_in_extent_set;
  int32			dbs_initial_gen; /* generic no of exe tat inited the db */
  char 			dbs_id[16]; /*!< Version ID of the server that made the database file */

  /* extent read stats and extent cache for adaptively migrating extents to faster persistent storage */
  dp_addr_t		dbs_exts_inext_ts;
  ext_ts_t *		dbs_ext_ts;
  unsigned char *	dbs_ext_ref_ct;
  dk_mutex_t *		dbs_ext_cache_mtx[DBS_EC_N_SETS];
  dk_hash_t *	dbs_ext_cache[DBS_EC_N_SETS];
  ext_ref_t *	dbs_er_waiting[DBS_EC_N_SETS];
  disk_segment_t *	dbs_cache_seg;
  dp_addr_t *	dbs_ec_to_dp;  /* at location corresponding to ext cache entry, the cached ext no. -1 means vacant */
  db_buf_t *		dbs_cache_dirty; /* bit set per extent in cache if this is different from copy in slower storage */
  char 			dbs_cfg_page_dt[DT_LENGTH];

  ol_backup_ctx_t	dbs_bp;
} ;

#define DBS_EC_ENTER(dbs, ext)  mutex_enter (dbs->dbs_ext_cache_mtx[ext % DBS_EC_N_SETS])
#define DBS_EC_LEAVE(dbs, ext)  mutex_leave (dbs->dbs_ext_cache_mtx[ext % DBS_EC_N_SETS])



/* dbs_type */
#define DBS_PRIMARY 0
#define DBS_SECONDARY 1
#define DBS_TEMP 2
#define DBS_RECOVER 3
#define DBS_ELASTIC 4


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



typedef struct chash_page_s
{
  union {
    struct {
      short	chp_flags;
      int	chp_fill;
      struct chash_page_s *	chp_next;
    } h;
    dtp_t	pad[16];
  } h;
  dtp_t	chp_data[PAGE_DATA_SZ + 4];
} chash_page_t;


typedef struct chash_s
{
  sql_type_t *		cha_sqt;
  sql_type_t *		cha_new_sqt;
  char			cha_n_keys;
  char		cha_n_dependent;
  short		cha_null_flags;		/*!< offset of null in entry (dependance may have nulls, keys too) */
  char		cha_unique; /* guaranteed unique/happens to be unique/nott unique.  If not unique, entries have a next pointer at end. */
  char			cha_is_1_int; /* key is 1 int or iri and no dependent and no duplicates, all data is in the chash array, no separate rows  */
  char			cha_is_1_int_key; /* key is single int or iri */
  char		cha_rehash_reqd;
  char		cha_is_parallel; /* hash join temp filled on multiple threads */
  char			cha_error;
  char			cha_hash_last; /* if hash join cha where hash filled after all rows are received */
  short		cha_threads;
  short		cha_rehash_ack_threads; /* if parallel fill and rehash needed, count of threads that have stopped to allow the rehash */
  short		cha_first_len;
  short		cha_next_len;
  short		cha_next_ptr;
  uint32			cha_n_partitions;
  int64			cha_size;
  int64			cha_count;
  int64			cha_distinct_count;
  int64		cha_n_in; /* for gby, no of sets processed */
  struct chash_s *	cha_partitions;
  int64 **		cha_array;
  int64 ** 		cha_exceptions;
  int			cha_exception_fill;
  uint32		cha_n_bloom;
  uint64 *		cha_bloom;
  chash_page_t *	cha_current;
  chash_page_t *		cha_current_data;
  mem_pool_t *		cha_pool;
  struct hash_area_s *	cha_ha;
  buffer_desc_t **		cha_bufs;
  int			cha_bufs_fill;
  int64		cha_reserved;
  chash_page_t *	cha_init_page;
  chash_page_t *	cha_init_data;
  du_thread_t *		cha_wait_excl;	/* exclusive owner of the chash */
  dk_set_t 		cha_waiting;    /* thread waiting on this */
  char 			cha_oversized;
} chash_t;

/* cha_unique */
#define CHA_ALWAYS_UNQ 1
#define CHA_UNQ 2
#define CHA_NON_UNQ 3
#define CHA_EMPTY 0xdeadbeefbadefeed

/* cha_rehash_reqd */
#define CHA_REHASH 1
#define CHA_RETYPE 2


typedef int (*cha_cmp_t) (chash_t * cha, int64 * ent, db_buf_t ** key_vecs, int row_no, dtp_t * nulls);
typedef int (*cha_ent_cmp_t) (chash_t * cha, int64 * ent1, int64 * ent2);


struct hash_index_s
{
  mem_pool_t *		hi_pool;
  id_hash_t *		hi_memcache;
  chash_t *		hi_chash;
  uint64		hi_cl_id; /* if cluster hash join temp, id for reference */
  dk_hash_t *	hi_thread_cha; /* when filling hash join chash, maps from thread to cha */
  int			hi_size;
  char			hi_is_unique;
  int64			hi_count;
#ifdef OLD_HASH
  hash_inx_elt_t **	hi_elements;
#endif
  dk_set_t 	hi_pages;
  int		hi_page_fill;
  index_tree_t *	hi_it;
  dp_addr_t		hi_last_dp;
  int			hi_hash_buf_fill; /* how much of last page filled */
  dp_addr_t	hi_last_source_dp;
  dp_addr_t 	*hi_buckets;
  dk_hash_t     *hi_source_pages;
  index_tree_t  *hi_source_tree;
  char		hi_lock_mode;
  char		hi_isolation;
  char 		hi_memcache_from_mp;
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
    slice_id_t		it_slice; /* for elastic, where a key has a  tree in every slice, this identifies the slice this belongs to */
    buffer_desc_t * volatile	it_root_image;
    int volatile		it_root_image_version;
    unsigned short		it_root_version_ctr;
    char		it_is_single_page;
    buffer_desc_t *	it_root_buf;
    dk_mutex_t *	it_lock_release_mtx;
    hash_index_t * 	it_hi; /* Ifhash index */
    dp_addr_t	it_hash_first;
    char		it_shared;
    char		it_hi_isolation; /* if hash index, isolation used for filling this */
    int		it_ref_count; /* if hash inx, count of qi's using this */
    dk_set_t 	it_geo_registered; /* a geo inx needs itc list for extra invalidate */
    hi_signature_t *	it_hi_signature;
    dk_set_t 		it_waiting_hi_fill; /* if thi is a hash inx being filled, list of threads waiting for the fill to finish */
    index_tree_t *	it_hic_next; /* links for LRU queue of hash indices */
    index_tree_t *	it_hic_prev;
    long		it_last_used;
    int			it_hi_reuses; /* if hash inx, count of reuses */
    bitf_t		it_all_in_own_em:1;
    bitf_t		it_blobs_with_index:1;
    dp_addr_t		it_n_index_est; /* estimate of index pages */
    dp_addr_t		it_n_blob_est; /* estimate of blob pages */
    extent_map_t *	it_extent_map;
    it_map_t *		it_maps;
    dk_hash_t *		it_col_extent_maps;
};


/* it_shared */
#define HI_PRIVATE 0
#define HI_OK 1
#define HI_RETRY 2
#define HI_FILL 3
#define HI_OBSOLETE 4

#define HI_CHASH  5

#define IN_TXN \
  mutex_enter (wi_inst.wi_txn_mtx);

#define LEAVE_TXN \
  mutex_leave (wi_inst.wi_txn_mtx)

#define ASSERT_IN_TXN \
  ASSERT_IN_MTX (wi_inst.wi_txn_mtx)

#define ASSERT_OUTSIDE_TXN \
  ASSERT_OUTSIDE_MTX (wi_inst.wi_txn_mtx)

#define IN_HIC \
  mutex_enter (hash_index_cache.hic_mtx)

#define LEAVE_HIC \
  mutex_leave (hash_index_cache.hic_mtx)

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
    char		sp_min_op; /* compare operator for lower bound */
    char		sp_max_op; /* if this is a range match, compare op for upper bound */
    char		sp_is_reverse; /* true if inserting a DESC sorted item */
    unsigned char		sp_col_filter;
    short			sp_min;  /* index into itc_search_params */
    short			sp_max; /* ibid */
    search_spec_t *	sp_next;
    dbe_col_loc_t	sp_cl;  /* column on key, if key on page matches key in compilation */
    dbe_column_t *	sp_col; /* col descriptor, use for finding the col if key on page is obsolete */
    struct state_slot_s *sp_min_ssl;  /* state slot for initing   the cursor's  itc_search_params[sp_min] */
    struct state_slot_s *sp_max_ssl;
    collation_t	 *sp_collation;
    char		sp_like_escape;
  };


typedef struct hash_range_spec_s
{
  /* if hash partitioning, test that hash no in range.  Occurs as sp_min_ssl in search_spec_t  */
  struct state_slot_s **	hrng_ssls;
  struct state_slot_s *		hrng_part_ssl;
  ssl_index_t	hrng_min;
  ssl_index_t	hrng_max;
  char		hrng_flags; /* range filter only, use bloom, not in, not exists in invisible hash join */
  struct hash_source_s *	hrng_hs;
  struct state_slot_s *	hrng_ht;
  struct state_slot_s *	hrng_ht_id;
  struct state_slot_s *	hrng_dc; /* temp dc for decoding a ce */
} hash_range_spec_t;


/* hrng_flags */
#define HR_NOT 1 /* true if not found */
#define HR_NO_BLOOM 2 /* bloom not selective, do not check */
#define HR_RANGE_ONLY 4
#define HRNG_IN 8 /* in pred with literals */



struct row_range_s
{
  row_no_t	r_first;
  row_no_t	r_end;
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
#define PA_READ_ONLY 2

#define ITC_LANDED_PA(itc) \
  (PA_READ_ONLY == (itc)->itc_dive_mode ? PA_READ : PA_WRITE)

#define ITC_DIVE_PA(itc) \
  (PA_WRITE == (itc)->itc_dive_mode ? PA_WRITE : PA_READ)

#define BUF_RO_REG_ENTER(itc, buf)					\
{ \
  if (!buf->bd_is_write) {\
    it_map_t * itm = IT_DP_MAP (itc->itc_tree, buf->bd_page); \
    if (ITC_CURSOR == itc->itc_type && (itm == itc->itc_itm1 || itm == itc->itc_itm2)) \
    ro_entered = NULL; \
  else  \
    mutex_enter (ro_entered = &itm->itm_mtx); \
  } \
}


#define BUF_RO_REG_LEAVE(itc, buf)				\
  if (ro_entered) mutex_leave (ro_entered);

#define ITC_STORAGE(itc) (itc)->itc_space->isp_tree->it_storage

#define ITC_AT_END -1 /* itc_map_pos when at end of buffer in derection of read */
#define ITC_DELETED -2 /* during page rewrite, just delete, goes to next non-delete or to end if none */

    /* placeholder_t i the common superclass of a placeholder, a bookmark whose position survives index updates, and of the index tree cursor */

#define PLACEHOLDER_MEMBERS \
  bitf_t		itc_type:3;  \
  bitf_t		itc_is_on_row:1; \
  bitf_t		itc_is_registered:1;	\
  bitf_t		itc_desc_order:1; /* true if reading index from end to start */ \
  char			itc_lock_mode; \
  short			itc_map_pos; \
  row_no_t		itc_col_row; \
  volatile dp_addr_t		itc_page; \
  dp_addr_t		itc_owns_page;  /* cache last owned lock */ \
  buffer_desc_t *	itc_buf_registered; \
  it_cursor_t *		itc_next_on_page; \
  index_tree_t *	itc_tree; \
  bitmap_pos_t		itc_bp

#define itc_row_no itc_bp.bp_value

#define ITC_PLACEHOLDER_BYTES \
	((int)(ptrlong)(&((it_cursor_t *)0x0)->itc_to_reset))

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

#define MAX_SEARCH_PARAMS (TB_MAX_COLS + 10)

#define RA_MAX_ROOTS 80

#define SQLO_RATE_NAME "rnd-stat-rate"

typedef enum { RANDOM_SEARCH_OFF = 0, RANDOM_SEARCH_ON = 1, RANDOM_SEARCH_AUTO = 2 ,
RANDOM_SEARCH_COND = 3} random_search_mode;

typedef int (*read_hook_t)(it_cursor_t * itc, buffer_desc_t * buf_from, dp_addr_t dp);

typedef struct sp_stat_s
{
  search_spec_t *	spst_sp;
  int			spst_in;
  int			spst_out;
  int64		spst_time;

} sp_stat_t;


struct it_cursor_s
  {
    PLACEHOLDER_MEMBERS;

    char		itc_to_reset; /* what level of change took place while itc waited for page buffer */
    char		itc_max_transit_change; /* quit waiting and do not enter the buffer if itc_transit_change >= this */
    char		itc_acquire_lock; /*when wait over want to own it? */
    char 		itc_search_mode; /* unique match or not */
    char		itc_isolation;
    unsigned char	itc_key_spec_nth;
    char		itc_has_blob_logged:3; /*if blob to log, can't drop blob when inlining it until commit */
    char		itc_random_search:3;
    bitf_t		itc_is_allocated:1;
    bitf_t		itc_dive_mode:2;
    bitf_t		itc_at_data_level:1;
    bitf_t		itc_landed:1; /* true if found position on or between leaves, false if in initial descent through the tree */
    bitf_t		itc_no_bitmap:1;  /* ignore bitmap logic if on bitmap inx */
    bitf_t		itc_bm_insert:1; /* in bm insert, do not consider delete flag on rows encountered */
    bitf_t		itc_desc_serial_landed:1; /* if set, failure to get first lock (right above the selected range) resets search */
    bitf_t		itc_desc_serial_reset:1;
    bitf_t		itc_is_outer:1; /* in vectored exec, put a row of nulls into the output if not found */
    bitf_t		itc_is_pure:1; /* if repeated search pars, can just copy the results, no side effects or deps on non-search par ssls */
    bitf_t		itc_asc_eq:1; /* params are asc sorted and condition is eq, use previous hit as start pos for finding next */
    bitf_t		itc_is_vacuum:1;
    bitf_t		itc_ac_parent_deld:1; /* set by autocompact to indicate that the parent page was popped off because of having only one leaf left */
    bitf_t		itc_is_geo_registered:1; /* in list of itcs in the geo index of itc_tree.  itc_tree can be a temp deld at time of itc free, so can't look in the tree*/
    bitf_t		itc_cl_results:1; /* in cluster server, send stuff in out map to the client node */
    bitf_t		itc_cl_local:1; /* if cluster but running local */
    bitf_t		itc_cl_batch_done:1; /* set if reset due ti batch done */
    bitf_t		itc_cl_set_done:1;
    bitf_t		itc_cl_from_temp:1; /* last search param is the id of the qf with the setp and the temp data */
    bitf_t		itc_cl_qf_any_passed:1; /* in cluster query frag output itc, used to know if nulls should be sent in oj */
    bitf_t		itc_app_stay_in_buf:2; /* in page_apply, stay inside if can.  Use itc_buf to return the buf if stayed */
    bitf_t		itc_keep_right_leaf:2; /* in vectored insert dive, record leaf ptr to the right of taken leaf */
    bitf_t		itc_non_txn_insert:1;
    bitf_t		itc_simple_ps:1; /* use fwd read ro rc page search func */
    bitf_t		itc_is_col:1;
    bitf_t		itc_reset_after_seg:1;
    bitf_t		itc_is_multiseg_set:1; /* in col layout, matches of key span multiple segs, need new random access if repeating eq key params */
    bitf_t		itc_bm_row_deleted:1;
    bitf_t		itc_multistate_row_specs:1;
    bitf_t		itc_col_need_preimage:1; /* whether need to fetch any pre-image of uncommitted updated in col filter/decode */
    bitf_t		itc_hash_row_spec:2;
    bitf_t		itc_value_ret_hash_spec:1; /* set if last hash spec sets result columns.  Must always be last row spec, no reordering */
    bitf_t		itc_local_key_spec:1; /* set if key spec extended to represent range partitioned scan partitions */
    bitf_t		itc_col_prefetch:1; /* set if must preread next page's cols.  Off if all so far in memory */
    bitf_t		itc_must_kill_trx:1;
    bitf_t		itc_col_right_ins:1; /* set if col key ins should split at right of page, i.e.. asc insert */
    bitf_t		itc_is_ac:1;
    bitf_t		itc_col_ac_redo:1; /* should retry col autocompact of last page */
    bitf_t		itc_log_actual_ins:1; /* if log ins soft, fetch  or distinct key, log only if actual insert */
    char		itc_split_search_res;
    char		itc_prev_split_search_res; /* if exact params repeat, store how it was with the previous set */
    unsigned char 	itc_n_vec_sort_cols; /* how many first params to use for sorting the param rows */
    unsigned char	itc_search_par_fill;
    unsigned char	itc_owned_search_par_fill;
    unsigned char	itc_pars_from_end; /* no of places in search params used for temp cast search pars */
    short			itc_write_waits; /* wait history. Use for debug */
    short			itc_read_waits;
    short			itc_n_lock_escalations; /* no of times row locks escalated to page locks on this read.  Used for claiming page lock as first choice after history of escalating */
    short			itc_n_branches; /*when dividing a scan into sections per thread, this is the count of parallel threads */
    short			itc_temp_fill;
    short			itc_temp_max;
    short			itc_n_siblings;
    short			itc_nth_sibling;
    unsigned char	itc_geo_op;

    /* dp_addr_t		itc_parent_page; */
    dp_addr_t		itc_siblings_parent; /* the pages in itc siblings are children of this.  Use for checking that the siblings list has the right content */
    int			itc_n_pages_on_hold; /* if inserting, amount provisionally reserved for deltas made by tree split */
    int			itc_set;
    int			itc_n_sets;
    int		itc_n_results;
    int		itc_set_first; /* first res index of currenbt set.  -1 if current set begins before this result batch */
    int		itc_batch_size;
    int		itc_max_rows;
    int		itc_n_in_set;
    int		itc_first_set; /* if split into threads by sets, 1st set on this itc */
    int64		itc_rows_selected; /* count of rows selected based on index criteria.  A col seg counts for all the rows in it */
    int64		itc_rows_on_leaves; /* Cumulative row count on distinct leaf pages visited so far.  A col seg counts as a row here */
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
    v_out_map_t *	itc_v_out_map;
    search_spec_t *	itc_bm_col_spec; /* if set, this is the indexable condition on the bitmapped col */

    db_buf_t		itc_row_data; /* pointer in mid page buffer , where the itc's rows data starts */
    dbe_key_t *		itc_row_key;
    placeholder_t *	itc_boundary;
    placeholder_t *	itc_bm_split_left_side;
    /* hash index */
    buffer_desc_t *	itc_buf; /* cache the buffer when keeping buffer wired down between rows.  Can be done because always read only.  */
    buffer_desc_t * 	itc_hash_buf; /* when filling a hash, the last buffer, constantly wired down, can be because always oen writer */
    struct word_stream_s *	itc_wst; /* for SM_TEXT search mode */
    caddr_t *		itc_out_state;  /* place out cols here. If null copy from itc_in_state */
    struct key_source_s *	itc_ks;
    int *			itc_param_order;
    v_out_map_t *		itc_vec_out_map;
    read_hook_t			itc_read_hook;
    dp_addr_t *			itc_siblings; /* sibling pages to the right of the present leaf */
    db_buf_t		itc_temp;
    /* data areas. not cleared at alloc */
    caddr_t		itc_search_params[MAX_SEARCH_PARAMS];
    int			itc_same_parent_miss;
    int			itc_same_parent_hit;
    /* column members.  Contiguous in this order, cleared together  */
    int			itc_col_first_set;
    int			itc_seg_end_set; /* first set no known not to have a match in current seg.  Based on earlier key part being gt end of seg, so do not look beyond this on later key parts */
    int			itc_ce_first_set;
    int			itc_ce_first_range;
    int			itc_row_of_ce;
    int			itc_first_filter_range;
    int 		itc_range_fill;
    short 		itc_nth_col_string;
    short		itc_nth_ce;
    short		itc_nth_key;
    row_no_t		itc_rows_in_seg;
    row_range_t *	itc_ranges;
    col_data_ref_t **	itc_col_refs;
    dtp_t *		itc_set_eqs;
    ce_ins_ctx_t *	itc_top_ceic;
    row_no_t *		itc_matches; /* row number in seg of rows matching row specs */
    struct row_lock_s *	itc_rl;
    search_spec_t *	itc_col_spec; /* in col random access, search spec of col now at hand */
    buffer_desc_t *	itc_col_leaf_buf; /* The row-wise leaf page on which the itc is landed.  */
    caddr_t *		itc_anify_cache;	/* If params are boxed, as in constants, and col ops want a dv string, use this to keep dv string versions */
    int			itc_anify_fill;
    int			itc_match_sz;
    int		itc_n_matches;
    int			itc_match_in;
    int			itc_match_out;
    sp_stat_t *	itc_sp_stat;
    db_buf_t		itc_last_cmp_ce;
    int64		itc_last_cmp_value;
    int			itc_last_cmp_row;
    char		itc_is_last_col_spec;
    short		itc_n_row_specs;
    dp_addr_t		itc_last_checked_page;
    /* end of column related */
    caddr_t		itc_owned_search_params[MAX_SEARCH_PARAMS];
    lock_trx_t *	itc_lock_lt; /* the lt that is the owner of a new lock being made.  May be different from itc_ltrx if that is a branch of a mt write txn.  If main branch is no longer going, this will be itc_ltrx and the locking will not finish but will bust. */
    sp_stat_t		itc_pre_sp_stat[3];
    extent_map_t *	itc_hold_em; /* if pages on hold, record where so they can be returned if the em changes */
    row_delta_t **	itc_vec_rds;
    row_delta_t *	itc_right_leaf_key; /* if itc_keep_right_bound, put the key values here */
    short			itc_ra_root_fill;
    int			itc_n_reads;
    int			itc_nth_seq_page; /* in sequential read, nth consecutive page entered.  Use for starting read ahead.  */
    dp_addr_t		itc_vec_ins_last;
    int			itc_vec_ins_misses;
    placeholder_t *	itc_bm_split_right_side;
    int			itc_root_image_version;
    short		itc_ins_flags;
    char		itc_bm_spec_replaced; /* true if bm inx dive set the key_spec */
    char		itc_cl_org_desc;
    dp_addr_t		itc_ra_root[RA_MAX_ROOTS];
    buffer_desc_t *	itc_buf_entered; /* this is set to the entered buf when another thread enters this itc into a buf as a result of page_leave_inner on that other thread */
    key_spec_t 	itc_cl_org_spec;
    dk_set_t	itc_ac_non_leaf_splits;
    struct {
      char 	mode;
      int	sample_size;  /* stop random search after this many rows */
      int	n_sample_rows; /* count of rows retrieved in random traversal */
      int	segs_sampled;
      int	rows_in_segs;
      dk_hash_t *	cols;	/* hash from de_col_t to col_stat_t *for random sample col stats. */
      struct tb_sample_s *	smp;
      int		n_rows_sampled;
      int		n_row_spec_matches;
    } itc_st;

  };

/* itc_row_hash_spec */
#define RSP_CHECKED 1
#define RSP_CHANGED 2

/* itc_keep_right_leaf */
#define ITC_RL_NONE 0 /* do not follow */
#define ITC_RL_INIT 1 /* keep track, not set yet */
#define ITC_RL_LEAF 2 /* itc_right_leaf_key contains the key of the next page */
#define ITC_RIGHT_EDGE 3 /* no leaves to the right */

/* itc_app_stay_in_buf */
#define ITC_APP_LEAVE 0 /* page_apply always leaves */
#define ITC_APP_STAY 1 /* page_apply stays in buffer if can */
#define ITC_APP_STAYED 2 /* the itc did stay inside, itc_buf is set */

/* stat mode */
#define ITC_STAT_ANGLE 1



#define ITC_NULL_CK(itc, cl) \
  (itc->itc_row_data[cl.cl_null_flag[IE_ROW_VERSION (itc->itc_row_data)]] & cl.cl_null_mask[IE_ROW_VERSION (itc->itc_row_data)])

#define ROW_INT_COL(buf, row, rv, cl, ref, n) \
{\
  short __off = (cl).cl_pos[rv];\
  if ((cl).cl_row_version_mask & rv)\
    {\
      unsigned short __irow2 = SHORT_REF (row + __off);\
      db_buf_t __row2 = buf->bd_buffer + buf->bd_content_map->pm_entries[__irow2 & ROW_NO_MASK];\
      __off = (cl).cl_pos[IE_ROW_VERSION(__row2)];\
      n = ref (__row2 + __off) + (__irow2 >> COL_OFFSET_SHIFT);\
    }\
  else \
    n =ref(row + __off); \
}


/* when searching, do you set a lock before returning hit?  Note that serializable sets the lock before checking the hit */
#define itc_lock_after_match(itc) \
  ((ISO_REPEATABLE == itc->itc_isolation || (PL_EXCLUSIVE == itc->itc_lock_mode && itc->itc_isolation == ISO_COMMITTED)) \
   && itc->itc_page != itc->itc_owns_page)
#define ROW_FIXED_COL(buf, row, rv, cl, ptr) \
{\
  short __off = (cl).cl_pos[rv];\
  if ((cl).cl_row_version_mask & rv)\
    {\
      int __irow2 = SHORT_REF (row + __off);\
      db_buf_t __row2 = buf->bd_buffer + buf->bd_content_map->pm_entries[__irow2 & ROW_NO_MASK];\
      __off = (cl).cl_pos[IE_ROW_VERSION(__row2)];\
      ptr = __row2 + __off;\
    }\
  else \
    ptr = row + (cl).cl_pos[rv];\
}

#define ITC_FREE_SP_STAT(itc) \
  { if (itc->itc_is_col && itc->itc_sp_stat  && itc->itc_sp_stat != &itc->itc_pre_sp_stat[0]) {itc_free_box (itc, (caddr_t)itc->itc_sp_stat); itc->itc_sp_stat = NULL; }}

#define ITC_SAVE_ROW_SPECS(itc) \
  { search_spec_t * __save_sp = itc->itc_row_specs; \
    sp_stat_t * __save_sps = itc->itc_sp_stat; \
    short __save_n_sps = itc->itc_n_row_specs;  \
    sp_stat_t __save_pre[3]; \
    memcpy_16 (&__save_pre, &itc->itc_pre_sp_stat, sizeof (itc->itc_pre_sp_stat));

#define ITC_NO_ROW_SPECS(itc) {itc->itc_row_specs = NULL; itc->itc_sp_stat = NULL; itc->itc_n_row_specs =  0;}

#define ITC_RESTORE_ROW_SPECS(itc) \
  ITC_FREE_SP_STAT (itc); \
  itc->itc_row_specs = __save_sp; \
  itc->itc_sp_stat = __save_sps; \
  itc->itc_n_row_specs = __save_n_sps; \
  memcpy_16 (&itc->itc_pre_sp_stat, &__save_pre, sizeof (itc->itc_pre_sp_stat)); \
}


#define ROW_STR_COL(key, buf, row, cl, p1, l1, p2, l2, offset) \
  kc_var_col (key, buf, row, cl, &p1, &l1, &p2, &l2, &offset)

#define KEY_PRESENT_VAR_COL(key, row, cl, off, len)\
{\
  row_ver_t rv = IE_ROW_VERSION (row);\
  len = (cl).cl_pos[rv];\
  if (CL_FIRST_VAR == len)\
    {\
      len = SHORT_REF (row + key->key_length_area[rv]);\
      off = IE_KEY_VERSION (row) ? key->key_row_var_start[rv] : key->key_key_var_start[rv];\
      len -= off;\
    }\
  else \
    {\
      off = SHORT_REF (row - len) & COL_VAR_LEN_MASK;\
      len = SHORT_REF (row + 2 - len) - off;\
    }\
}


#define ITC_PRESENT_VAR_COL(itc, cl, off, le) \
  KEY_PRESENT_VAR_COL (itc->itc_insert_key, itc->itc_row_data, cl, off, len)

#define ROW_LENGTH(row, key, len) \
len = row_length (row, key)


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
/* when calling page_wait_access, the itc_max_transit_change is one of these.
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
  memzero ((ITC) itc, ((ptrlong) &(itc)->itc_search_params) - ((ptrlong) itc)); \
  itc->itc_type = ITC_CURSOR; \
  itc->itc_ltrx = trx; \
  itc->itc_lock_mode = PL_SHARED; \

#define ITC_START_SEARCH_PARS(it) \
  it->itc_search_par_fill =0, \
    it->itc_owned_search_par_fill =0,		\
    it->itc_pars_from_end = 0

#define ITC_SEARCH_PARAM(it, par) \
{ \
  it->itc_search_params[it->itc_search_par_fill++] =  ((caddr_t) (par)); \
}



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

#define PM_MAX_ENTRIES	 (PAGE_DATA_SZ / 3)


struct page_map_s
  {
    /* For a buffer with index tree content, this struct  holds the starting positions of all entries in index order plus avail. space */
    short	pm_size; /* number of entries actually in pm_entries.  Different sizes of map are allocated for different buffers since having a page full of minimum length entries is very rare */
    short		pm_count;  /* count of rows. This many first entries in pm_entries are valid */
    short		pm_filled_to; /* First free byte of the page's trailing contiguous free space */
    short		pm_bytes_free; /* count of free bytes, including gaps.  If a row of this or less size is inserted, it will fit, maybe needing page compaction */
    short		pm_n_non_comp; /*n inserts that have not been checked for compressible cols */
    short		pm_entries[PM_MAX_ENTRIES]; /* the start offsets of the index entries  on the page */
  };


#define PM_ENTRIES_OFFSET ((int) (ptrlong) &((page_map_t *)0)->pm_entries)

#define DO_ROWS(buf, map_pos, row, key)		\
{ \
  int map_pos; \
  for (map_pos = 0; map_pos < buf->bd_content_map->pm_count; map_pos++) \
  {\
    db_buf_t row = buf->bd_buffer + buf->bd_content_map->pm_entries[map_pos];

#define END_DO_ROWS } }



/* the different standard sizes of page_map_t */
#define PM_SZ_1 50
#define PM_SZ_2 200
#define PM_SZ_3 720
#define PM_SZ_4 (PM_MAX_ENTRIES)


#define PM_SIZE(ct) \
  (ct < PM_SZ_1 ? PM_SZ_1 : (ct < PM_SZ_2 ? PM_SZ_2 : (ct < PM_SZ_3 ? PM_SZ_3 : (ct <= PM_SZ_4 ? PM_SZ_4 : (GPF_T1 ("pm size overflow"), 0)))))
extern resource_t * pm_rc_1;
extern resource_t * pm_rc_2;
extern resource_t * pm_rc_3;
extern resource_t * pm_rc_4;

#define PM_RC(sz) (sz == PM_SZ_1 ? pm_rc_1 : (sz == PM_SZ_2 ? pm_rc_2 : (sz == PM_SZ_3 ? pm_rc_3 : (sz == PM_SZ_4 ? pm_rc_4 : (resource_t *)(GPF_T1("not a valid pm size"), NULL)))))





#define ITC_REAL_ROW_KEY(itc) \
{ \
  itc->itc_row_key = itc->itc_insert_key->key_versions[IE_KEY_VERSION (itc->itc_row_data)];\
}


/*#define BUF_DEBUG*/
#define buf_dbg_printf(a) /*printf a*/

#define bd_readers bdf.r.readers
#define bd_is_write bdf.r.is_write
#define bd_being_read bdf.r.being_read
#define bd_is_dirty bdf.r.is_dirty
#define bd_is_ro_cache bdf.r.is_ro_cache
#define bd_batch_id bdf.r.batch_id

#if defined (MTX_DEBUG) && !defined (PAGE_DEBUG)
#define PAGE_DEBUG
#endif

#ifdef NDEBUG
#undef PAGE_DEBUG
#endif

struct buffer_desc_s
{
  /* Descriptor of a page buffer.  Read/write gate and other fields */
  union {
    int64	flags; /* allow testing for all 0's with a single compare.  All zeros means candidate for reuse. */
    struct {
      short readers; /* count of threads with read access */
      /* the below flags are chars and not bit fields.
       * If bit fields, there is a read+write for setting and cache coherence will not protect against
       * a change of a bit between the read and the write.  So for cache coherence the flags must be
       * individually stable so that you do not end up setting neighbor flags to their former values.
       * The write will hit an obsolete cache line and will reload the line but the other bits will
       * still come from the read that was done before the change.  */
      char	is_write;  /* if any thread the exclusive owner of this */
      char	being_read; /* is the buffer allocated for a page and awaiting the data coming from disk */
      char	is_dirty; /* Content changed since last written to disk */
      char	is_ro_cache;
      char	is_read_aside;
      unsigned char 	batch_id;
    } r;
  } bdf;
  bp_ts_t		bd_timestamp; /* Timestamp for estimating age for buffer reuse */
  it_cursor_t *	bd_read_waiting;  /* list of cursors waiting for read access */
  it_cursor_t *	bd_write_waiting; /* itc waiting for write access */

  db_buf_t		bd_buffer; /* the 8K bytes for the page */
  page_map_t *	bd_content_map; /* only if content is an index page */
  page_lock_t *	bd_pl; /* if lock associated, it's cached here in addition to the tree's hash */

  union {
    buffer_desc_t *	next; /* Link to next if this is in free set or inc backup set.  If regular buffer, this is a link to the next unused if this buffer is unused, else null */
    it_cursor_t *	registered;
  } bn;
  dp_addr_t		bd_page; /* The logical page number */
  dp_addr_t		bd_physical_page; /* The physical page number, can be different from bd_page if remapped */

  buffer_pool_t *	bd_pool;
  index_tree_t *	bd_tree; /* when caching a page, this is  the index tree  to which the page belongs */
  dbe_storage_t * 	bd_storage; /* the storage unit for reading/writing the page */
  io_queue_t *	 bd_iq; /* iq, if buffer in queue for read(write */
  buffer_desc_t *	bd_iq_prev; /* next and prev in double linked list of io queue */
  buffer_desc_t *	bd_iq_next;
#if defined (PAGE_DEBUG) | defined (MTX_DEBUG)
  du_thread_t *	bd_writer; /* for debugging, the thread which has write access, if any */
  char * 		bd_enter_file;
  char * 		bd_leave_file;
  short 			bd_enter_line;
  short 			bd_leave_line;
  short                  bd_set_wr_line;
  short		bd_delta_line;
  char 			bd_el_flag;	/* what operation was last: 1-enter, 2-leave */
  int		bd_ck_ts;
  int		bd_delta_ts;
  char *                bd_set_wr_file;
  thread_t *		bd_thr_el;
#endif
#ifdef PAGE_TRACE
  long		bd_trx_no;
#endif
#ifdef BUF_DEBUG
  index_tree_t *	bd_prev_tree;
#endif
};

#define BUF_ROW(buf, pos) ((buf)->bd_buffer + (buf)->bd_content_map->pm_entries[pos])

#ifdef PAGE_DEBUG
#define BUF_DBG_ENTER_1(buf, __file, __line) \
    do { \
      if (buf) { \
	thread_t * __self = THREAD_CURRENT_THREAD; \
	(buf)->bd_enter_file = __file; \
	(buf)->bd_enter_line = __line; \
	(buf)->bd_el_flag = 1; \
	(buf)->bd_thr_el = __self; \
	if (!__self->thr_pg_dbg) \
	  __self->thr_pg_dbg = (void *) hash_table_allocate (31); \
	sethash ((void *)(buf), (dk_hash_t *) __self->thr_pg_dbg, (void*)(ptrlong)(buf)->bd_page); \
      } \
    } while (0)
#define BUF_DBG_LEAVE_1(buf, __file, __line) \
    do { \
      if (buf) { \
	thread_t * __self = THREAD_CURRENT_THREAD; \
	if (__self->thr_pg_dbg) { \
	  remhash ((void*) (buf), (dk_hash_t *) __self->thr_pg_dbg); \
	} else if ((buf)->bd_el_flag == 1) \
	  log_error ("Page debug info missing at %s:%ld, entered at %s:%ld", __file, __line, (buf)->bd_enter_file, (buf)->bd_enter_line); \
	(buf)->bd_leave_file = __file; \
	(buf)->bd_leave_line = __line; \
	(buf)->bd_el_flag = 2; \
	(buf)->bd_thr_el = __self; \
      } \
    } while (0)
#define BUF_DBG_LEAVE(buf) BUF_DBG_LEAVE_1((buf), file, line)
#define BUF_DBG_LEAVE_INL(buf) BUF_DBG_LEAVE_1((buf), __FILE__, __LINE__)
#define BUF_DBG_ENTER(buf) BUF_DBG_ENTER_1((buf), file, line)
#define BUF_DBG_ENTER_INL(buf) BUF_DBG_ENTER_1((buf), __FILE__, __LINE__)

#define THR_DBG_PAGE_CHECK \
  do \
  { \
    thread_t * self = THREAD_CURRENT_THREAD; \
    dk_hash_iterator_t hit; \
    buffer_desc_t * buf; \
    ptrlong page; \
    dk_hash_iterator (&hit, (dk_hash_t *) self->thr_pg_dbg); \
    while (NULL != self->thr_pg_dbg && dk_hit_next (&hit, (void**) &buf, (void**) &page)) \
      { \
	if (buf && buf->bd_tree && buf->bd_tree->it_key->key_id == KI_TEMP) continue; \
	GPF_T1 ("Buffer left occupied after thread is done"); \
      } \
    if (NULL != self->thr_pg_dbg) clrhash ((dk_hash_t *) self->thr_pg_dbg); \
  } \
  while (0)

#else
#define BUF_DBG_ENTER(buf)
#define BUF_DBG_ENTER_INL(buf)
#define BUF_DBG_LEAVE(buf)
#define BUF_DBG_LEAVE_INL(buf)
#define THR_DBG_PAGE_CHECK
#endif

#define bd_registered bn.registered
#define bd_next bn.next
#define BUF_AGE(buf) (buf->bd_pool->bp_ts - buf->bd_timestamp)

/* mark as recently used */
#define BUF_TOUCH(buf) \
{ \
  (buf)->bdf.r.is_read_aside = 0; \
  (buf)->bd_timestamp = (buf)->bd_pool->bp_ts;		\
  if ((bp_hit_ctr++ & 0x1f) == 0)			\
    (buf)->bd_pool->bp_ts++;				\
}


#define BUF_TICK(buf) buf->bd_pool->bp_ts++;

#define BUF_NONE_WAITING(buf) \
(!buf->bd_write_waiting && !buf->bd_read_waiting && !buf->bd_being_read)

#if defined (PAGE_DEBUG) | defined (MTX_DEBUG)
#define BD_SET_IS_WRITE(bd, f) \
do { \
  (bd)->bd_is_write = f;			    \
  (bd)->bd_set_wr_file = __FILE__; \
  (bd)->bd_set_wr_line = __LINE__; \
 if (f) { (bd)->bd_writer = THREAD_CURRENT_THREAD; BUF_PW (bd); }	\
 else { (bd)->bd_writer = NULL; BUF_PR (bd); };				\
} while (0)
#else
#define BD_SET_IS_WRITE(bd, f) \
  (bd)->bd_is_write = f

#endif


#ifdef BUF_BOUNDS
extern buffer_desc_t * bounds_check_buf;

#define BUF_BOUNDS_CHECK(buf)  \
{ \
  unsigned short flags = SHORT_REF (buf->bd_buffer + DP_FLAGS); \
  if (DPF_INDEX == flags && !buf->bd_content_map) { bounds_check_buf = buf; GPF_T1 ("inx buffer without map");}; \
  if (flags >= DPF_LAST_DPF) { bounds_check_buf = buf; GPF_T1 ("bad dp_flags"); };  \
  if (BUF_END_MARK != LONG_REF (buf->bd_buffer + PAGE_SZ)) { bounds_check_buf = buf; GPF_T1 ("bad buffer end mark"); } \
}
#define BUF_ALLOC_SZ (PAGE_SZ + sizeof (int32))
#define BUF_END_MARK 0xfeedbeef
#define BUF_SET_END_MARK(buf) LONG_SET (buf->bd_buffer + PAGE_SZ, BUF_END_MARK)
#else
#define BUF_BOUNDS_CHECK(buf)
#define BUF_ALLOC_SZ PAGE_SZ
#define BUF_SET_END_MARK(buf)
#endif

/*#define BUF_ALLOC_CK*/

#ifdef BUF_ALLOC_CK
#undef BUF_ALLOC_SZ
#define BUF_ALLOC_SZ (PAGE_SZ + sizeof (int32))

int adler32_of_buffer (unsigned char *data, size_t len);
int32 sqlbif_rnd (int32* seed);
#define BUF_SET_CK(buf) do { \
	  int32 chk; \
  	  RAND_pseudo_bytes (buf->bd_buffer, PAGE_SZ); \
	  chk = adler32_of_buffer (buf->bd_buffer, PAGE_SZ); \
	  LONG_SET (buf->bd_buffer + PAGE_SZ, chk); \
} while (0)

#define BUF_CK(buf) do { \
	  int32 chk; \
	  chk = adler32_of_buffer (buf->bd_buffer, PAGE_SZ); \
	  if (chk != LONG_REF (buf->bd_buffer + PAGE_SZ)) GPF_T1 ("bad buffer checksum"); \
} while (0)

#else
#define BUF_SET_CK(buf)
#define BUF_CK(buf)
#endif




#define PFH_N_WAYS 29
#define PFH_MAX_COLS 5
#define PFH_N_SHORTS 4096
#define PFH_KV_ANY 255 /* in pfh_)kv when the kv is not yet set */


struct pf_hash_s
{
  short		pfh_start[PFH_MAX_COLS][PFH_N_WAYS];
  key_ver_t	pfh_kv; /* only this kv's keys are al;lowed in */
  short		pfh_hash[PFH_N_SHORTS];
  short		pfh_fill;
  short		pfh_n_cols; /* last cl_nth +1 that is inited */
  db_buf_t	pfh_page;
  page_fill_t *	pfh_pf;
};


typedef struct pf_var_s
{
  short		pfv_place;
  short		pfv_irow;
  short		pfv_next;
  short		pfv_len;
} pfe_var_t;


struct row_fill_s
{
  db_buf_t	rf_row;
  db_buf_t	rf_large_row;
  row_size_t	rf_space;
  row_size_t	rf_fill;
  short		rf_map_pos;
  dbe_key_t *	rf_key;
  pf_hash_t *	rf_pf_hash; /* if doing compressing copy, mark the places that have full values here */
  char		rf_is_leaf;
  char		rf_no_compress; /* do not try col compression */
};


struct  page_fill_s
{
  it_cursor_t *	pf_itc;
  dk_set_t	pf_left; /* if more than one buffers result, the leftmost is first, then the rest, except for the current */
  buffer_desc_t *	pf_org; /* use this to decode compression if getting stuff as rows */
  buffer_desc_t *	pf_current;
  pf_hash_t *		pf_hash;
  row_lock_t **	pf_rls;
  placeholder_t **	pf_registered;
  data_col_t *		pf_dc;
  mem_pool_t * 		pf_mp;
  int		pf_rl_fill;
  int		pf_cr_fill;
  char		pf_is_autocompact; /* when splitting, do not alloc real pages, just bufs with no disk page */
  char		pf_op;
  char		pf_rewrite_overflow;
  int		pf_dbg;
};


#define LOCAL_RF(rf, row, space, key)		\
  row_fill_t rf; \
  memset (&rf, 0, sizeof (rf)); \
  rf.rf_row = row;\
  rf.rf_space = space;\
  rf.rf_fill = key->key_row_var_start[0];\
  rf.rf_key = key;



#define RF_LARGE_CHECK(rf, off, len)\
{\
  int __off = off ? off : rf->rf_fill;\
  /*if (!!rf->rf_no_large && rf->rf_large_row) GPF_T1 ("rf_large_row not set"); */ \
  if (__off + len > MAX (rf->rf_space, MAX_ROW_BYTES)) GPF_T1 ("row fill overflow max bytes"); \
  if (__off + len > rf->rf_space)\
    {\
      memcpy (rf->rf_large_row, row, rf->rf_fill);\
      if (__off > rf->rf_fill) memset (rf->rf_large_row + rf->rf_fill, 0, __off - rf->rf_fill); \
      /* set at least __off worth but do not read more than rf_fill worth.  For valgrind. */ \
      row = rf->rf_row = rf->rf_large_row;\
      rf->rf_space = MAX_ROW_BYTES;\
    }\
}



struct row_delta_s
{
  char		rd_op;
  char		rd_make_ins_rbe; /* when plain on page, make ins rollback entry? */
  char		rd_copy_of_deleted; /* when writing a page with uncommitted deletes */
  char		rd_raw_comp_row; /* when copying and it is known that compression stays the same, rd_values is the row string */
  key_ver_t	rd_key_version; /* use this to see if left dummy or such */
  short		rd_map_pos;
  row_size_t	rd_non_comp_len;
  slice_id_t	rd_slice;
  char		rd_any_ser_flags;
  short		rd_non_comp_max;
  dp_addr_t		rd_leaf; /* if lp, if upd or ins concerns leaf ptr */
  dbe_col_loc_t **	rd_upd_change;
  dbe_key_t *		rd_key;
  caddr_t *		rd_values; /* if ins or upd, the values */
  short			rd_n_values;
  short			rd_temp_fill;
  short			rd_temp_max;
  char			rd_allocated;
  bitf_t		rd_cl_blobs_at_store:1; /* do not make blobs when reading the rd from cluster peer */
  db_buf_t		rd_temp; /* when copying, scratch space for non-allocd box images */
  row_lock_t *		rd_rl;
  it_cursor_t * 	rd_itc;
  caddr_t *		rd_qst;
  it_cursor_t *		rd_keep_together_itcs;
  db_buf_t 		rd_whole_row; /* if no compression anywhere, this is the row as it is on the page, self-contained,, insertable as is */
  short			rd_whole_row_len;
  short			rd_keep_together_pos;
  dp_addr_t		rd_keep_together_dp;
};

/* rd_allocated */
#define RD_AUTO 1
#define RD_ALLOCATED_VALUES 2
#define RD_ALLOCATED 3

/* rd_op */
#define RD_INSERT 1 /* 1 row, goes to rd_map_pos */
#define RD_DELETE 2 /* row at map pos rd_pos is deleted */
#define RD_UPDATE 3 /* row at rd_map_pos is replaced */
#define RD_LEAF_PTR 4 /* lp of lp at map pos rd_pos gets set to rd_leaf_ptr */
#define RD_LEFT_DUMMY 5
#define RD_UPDATE_LOCAL 6 /* replace of a row that does not affect any compressible */


#define MAX_ITCS_ON_PAGE 1000

typedef struct page_apply_frame_s
{
  placeholder_t *	paf_registered[MAX_ITCS_ON_PAGE];
  row_lock_t *	paf_rlocks[PM_MAX_ENTRIES];
  buffer_desc_t	paf_buf;
  page_map_t	paf_map;
  row_delta_t	paf_rd;
  dtp_t		paf_page[PAGE_SZ];
  caddr_t	paf_rd_values[TB_MAX_COLS];
  dtp_t paf_rd_temp[2 * MAX_ROW_BYTES];
} page_apply_frame_t;


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
    int64	iq_n_writes;
    int64	iq_sync_delay;
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


#define RA_MAX_BATCH 4000
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


extern int64 bdf_is_avail_mask; /* all bits on except read aside flag which does not affect reusability */

#ifdef PAGE_DEBUG
#define BUF_NEEDS_DELTA(b) ((b)->bd_delta_ts = (b)->bd_timestamp, (b)->bd_delta_line = __LINE__, 1)
#elif defined (MTX_DEBUG)
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
   && !buf->bd_read_waiting && !buf->bd_write_waiting && !buf->bd_iq)
#else
#define BUF_AVAIL(buf) \
  ((buf->bdf.flags & bdf_is_avail_mask) == 0		\
   && !buf->bd_read_waiting && !buf->bd_write_waiting && !buf->bd_iq)
#endif


#define BUF_CANCEL_WRITE(buf) \
  buf_cancel_write (buf)


/* comparison */

/* for cmp <, <= ==, >, >= the test & 15 is true. For all else test & 15 == 0*/
#define DVC_MATCH 1
#define DVC_LESS 2
#define DVC_GREATER 4
#define DVC_DTP_LESS (DVC_LESS | DVC_NOORDER)
#define DVC_DTP_GREATER	(DVC_GREATER | DVC_NOORDER)
#define DVC_NOORDER 8
#define DVC_NOT_IN_RANGE 32
#define DVC_RANGE_LESS (DVC_LESS | DVC_NOT_IN_RANGE) /* if left side is value from column ce, means that the right side cannot be in the same ce because of range but is of same dtp */
#define DVC_RANGE_GREATER	(DVC_GREATER | DVC_NOT_IN_RANGE)

#define DVC_INDEX_END 16
#define DVC_CMP_MASK 15 /* or of bits for eq, lt, gt */
#define DVC_UNKNOWN	64  /* comparison of SQL NULL */
#define DVC_QUEUED 128  /* in cluster, not known yet, added to batch */
#define DVC_INVERT_CMP(res) do { \
  switch (res & (DVC_LESS | DVC_GREATER)) \
    { \
    case DVC_LESS: res = (res & ~DVC_LESS) | DVC_GREATER; break; \
    case DVC_GREATER: res = (res & ~DVC_GREATER) | DVC_LESS; break; \
    } } while (0)

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
#define CMP_NOT_LIKE 64
#define CMP_HASH_RANGE 112  /* check hash no range and optionally do restricting hash join */
#define CMP_HASH_RANGE_ONLY 112 /* in max op to indicate that only hash no range is checked */

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
#define RST_GB_ENOUGH 7  /* streaming group by has full batch of groups */

#ifndef DEBUG
#define NO_ITC_DEBUG
#endif

#ifndef NO_ITC_DEBUG
# define FAILCK(it) if (! it -> itc_fail_context) GPF_T1("No fail context.");
#else
# define FAILCK(it)
#endif

# define ALLOC_CK(xx) dk_alloc_assert ((xx));
#ifdef MALLOC_DEBUG
# define ITC_ALLOC_CK(xx) if ((xx) -> itc_is_allocated) dk_alloc_assert ((((caddr_t)xx) - 8));
#else
# define ITC_ALLOC_CK(xx) ;
#endif


#define CHECK_SESSION_DEAD(lt, itc, buf)		\
{ \
  if (lt) \
    { \
      client_connection_t * cli = lt->lt_client; \
      char __term = cli ? cli->cli_terminate_requested : 0;			\
      if (__term && !wi_inst.wi_checkpoint_atomic) cli_terminate_in_itc_fail (cli, itc, buf); \
      if (cli && cli->cli_session && cli->cli_session->dks_to_close)	\
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
      CHECK_SESSION_DEAD (__lt, it, buf);		   \
      if ((__lt && __lt->lt_status != LT_PENDING)  \
|| (wi_inst.wi_is_checkpoint_pending && cpt_is_global_lock (__lt))) \
	{ \
	  if (__lt && !wi_inst.wi_checkpoint_atomic) \
	itc_bust_this_trx (it, buf, may_ret); \
}\
 }								\

#define LT_NEED_WAIT_CPT(lt) \
  (wi_inst.wi_is_checkpoint_pending  && \
   wi_inst.wi_cpt_lt != lt && !cpt_is_global_lock (lt))


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
  STRUCTURE_FAULT1("Structure fault. Crash recovery recommended.")


#define STRUCTURE_FAULT1(msg)			\
{ \
  if (assertion_on_read_fail) \
    GPF_T1 (msg); \
  else \
    longjmp_splice (&structure_fault_ctx, 1); \
}

extern char *run_as_os_uname;
extern long dbe_auto_sql_stats; /* from search.c */

extern int in_crash_dump;

#if defined (WITH_PTHREADS) && !defined (MTX_DEBUG) && !defined (MTX_METER)  && !defined (IN_ODBC_CLIENT)
#undef mutex_enter
#undef mutex_leave
#define mutex_enter(m)  pthread_mutex_lock (&((m)->mtx_mtx))
#define mutex_leave(m)  pthread_mutex_unlock (&((m)->mtx_mtx))
#endif

#if defined (SOLARIS) || defined (WIN32)
#define __builtin_prefetch(m) 0
#endif

#define SD_INT32 ((char **)-1)
#define SD_INT64 ((char **)-2)

typedef struct stat_desc_s
  {
    const char *   sd_name;
    long *   sd_value;
    char **   sd_str_value;
  } stat_desc_t;

extern stat_desc_t dbf_descs[];

typedef struct s_time_t
{
  uint32	sti_real;
  uint32	sti_cpu;
  uint32	sti_sys;
} sys_timer_t;

#define STI_START \
  { sys_timer_t __sti; sti_init (&__sti);

#define STI_END(total) \
  sti_cum (&total, &__sti); } \

void sti_init (sys_timer_t*);
void sti_cum (sys_timer_t * cum, sys_timer_t * start);

#endif /* _WI_H */

