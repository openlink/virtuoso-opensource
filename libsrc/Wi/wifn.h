/*
 *  wifn.h
 *
 *  $Id$
 *
 *  Internal Functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

#ifndef _WIFN_H
#define _WIFN_H

#include "wi.h"
#include "widisk.h"
#include "widd.h"
#include "schspace.h"
#include "../Dk/Dkhash64.h"

/* search.c */

void const_length_init (void);
extern numeric_t num_int64_max;
extern numeric_t num_int64_min;
void db_buf_length  (unsigned char * buf, long * head_ret, long * len_ret);
int box_serial_length (caddr_t box, dtp_t dtp);
extern short db_buf_const_length [256];
extern dtp_t dtp_canonical[256];

int  dv_composite_cmp (db_buf_t dv1, db_buf_t dv2, collation_t * coll);
int dv_compare (db_buf_t dv1, db_buf_t dv2, collation_t *collation, unsigned short offset);
int dv_compare_box (db_buf_t dv1, caddr_t box, collation_t *collation);
int pg_key_compare (buffer_desc_t * buf, int pos, it_cursor_t * it);
int pg_insert_key_compare (buffer_desc_t * buf, int pos, it_cursor_t * it);
void ksp_cmp_func (key_spec_t * ksp, unsigned char * nth);
void  ksp_nth_cmp_func (key_spec_t * ksp, char nth);

int  itc_hash_next (it_cursor_t * itc, buffer_desc_t * buf);
void search_inline_init (void);


int itc_like_compare (it_cursor_t * itc, buffer_desc_t * buf, caddr_t pattern, search_spec_t * spec);


#ifdef MALLOC_DEBUG
it_cursor_t * dbg_itc_create (const char *file, int line, void *, lock_trx_t *);
#define itc_create(a,b)  dbg_itc_create (__FILE__, __LINE__, a, b)
#else
it_cursor_t * itc_create (void *, lock_trx_t *);
#endif
void itc_free (it_cursor_t *);
void itc_clear (it_cursor_t * it);
void itc_free_owned_params (it_cursor_t * itc);

#define NEW_PLH(v) \
  placeholder_t * v = (placeholder_t*) dk_alloc_box_zero (sizeof (placeholder_t), DV_ITC); \
  v->itc_type = ITC_PLACEHOLDER;
placeholder_t * plh_allocate ();
int dv_compare (db_buf_t dv1, db_buf_t dv2, collation_t *collation, unsigned short offset);
int dv_compare_spec (db_buf_t db, search_spec_t * spec, it_cursor_t * it);
dp_addr_t leaf_pointer (db_buf_t row, dbe_key_t * key);
row_size_t page_gap_length (db_buf_t page, row_size_t pos);
buffer_desc_t * pl_enter (placeholder_t * pl, it_cursor_t * ctl_itc);
buffer_desc_t * page_reenter_excl (it_cursor_t * it);
int page_find_leaf (buffer_desc_t * buf, dp_addr_t lf);
int pg_skip_gap (db_buf_t page, int pos);
void itc_skip_entry (it_cursor_t * it, buffer_desc_t * buf);
void itc_prev_entry (it_cursor_t * it, buffer_desc_t * buf);


#define PS_LOCKS 0
#define PS_NO_LOCKS 1
#define PS_OWNED 2

int itc_search (it_cursor_t * it, buffer_desc_t ** buf_ret);
void itc_restart_search (it_cursor_t * it, buffer_desc_t ** buf);

int itc_page_search (it_cursor_t * it, buffer_desc_t ** buf_ret,
		     dp_addr_t * leaf_ret, int skip_first_key_cmp);
int itc_page_insert_search (it_cursor_t * it, buffer_desc_t ** buf);
int itc_page_split_search (it_cursor_t * it, buffer_desc_t ** buf);

void itc_from (it_cursor_t * it, dbe_key_t * key);
void itc_clear_stats (it_cursor_t *it);
void itc_from_keep_params (it_cursor_t * it, dbe_key_t * key);
void itc_from_it (it_cursor_t * itc, index_tree_t * it);
int itc_next (it_cursor_t * it, buffer_desc_t ** buf_ret);
int64 itc_sample (it_cursor_t * it);
int64 itc_local_sample (it_cursor_t * it);
unsigned int64 key_count_estimate (dbe_key_t * key, int n_samples, int upd_col_stats);
int key_n_partitions (dbe_key_t * key);
caddr_t key_name_to_iri_id (lock_trx_t * lt, caddr_t name, int make_new);
int  key_rdf_lang_id (caddr_t name);
caddr_t cl_find_rdf_obj (caddr_t obj);
rdf_box_t * key_find_rdf_obj (lock_trx_t * lt, rdf_box_t * rb);
caddr_t mdigest5 (caddr_t str);


void plh_free (placeholder_t * pl);
placeholder_t * plh_landed_copy (placeholder_t * pl, buffer_desc_t * buf);
placeholder_t * plh_copy (placeholder_t * pl);
buffer_desc_t * itc_set_by_placeholder (it_cursor_t * itc, placeholder_t * pl);


void itc_sqlr_error (it_cursor_t * itc, buffer_desc_t * buf, const char * code, const char * msg, ...)
#ifdef __GNUC__
                __attribute__ ((format (printf, 4, 5)))
#endif
;
void itc_sqlr_new_error (it_cursor_t * itc, buffer_desc_t * buf, const char * code, const char *virt_code, const char * msg, ...)
#ifdef __GNUC__
                __attribute__ ((format (printf, 5, 6)))
#endif
;


#define DB_BUF_TLEN(len, dtp, ptr) \
  len = db_buf_const_length [dtp]; \
  if (len == -1) len = (ptr) [1] + 2; \
  else if (len == 0) { \
    long __l, __hl; \
    db_buf_length (ptr, &__hl, &__l); \
    len = (int) (__hl + __l); \
  }

int buf_check_deleted_refs (buffer_desc_t * buf, int do_gpf);
void itc_set_last_safe (it_cursor_t * it, buffer_desc_t * buf);
void itc_from_dyn_sp (it_cursor_t * it, dbe_key_t * key);

int itc_ra_quota (it_cursor_t * itc);
struct ra_req_s *itc_read_ahead1 (it_cursor_t * itc, buffer_desc_t ** buf_ret);
void itc_read_ahead_blob (it_cursor_t * itc, struct ra_req_s *ra, int flags);
#define RAB_SPECULATIVE 1 /* to indicate speculative read ahead with random lookup, buffers should be inited fairly old and no touch for ones already in */

void itc_read_ahead (it_cursor_t * itc, buffer_desc_t ** buf_ret);
struct ra_req_s * itc_read_aside (it_cursor_t * itc, buffer_desc_t * buf, dp_addr_t dp);
void dbs_timeout_read_history (dbe_storage_t * dbs);


#define DV_IS_NULL(x) \
  (IS_BOX_POINTER ((x)) && DV_DB_NULL == box_tag ((x)))

#define DV_COMPARE_SPEC_W_NULL(r, cl, sp, it, buf)	\
  if (sp->sp_min_op == CMP_EQ) \
    { \
      r = page_col_cmp (buf, it->itc_row_data, cl, it->itc_search_params[sp->sp_min]); \
    } \
  else \
    { \
      row_ver_t rv = IE_ROW_VERSION (it->itc_row_data); \
      if (cl->cl_null_mask[rv] & (cl->cl_null_mask[rv] & it->itc_row_data[cl->cl_null_flag[rv]])) \
	{ \
	  if ((sp->sp_max_op != CMP_NONE && DV_IS_NULL (it->itc_search_params[sp->sp_max])) \
	      || (sp->sp_min_op != CMP_NONE && DV_IS_NULL (it->itc_search_params[sp->sp_min]))) \
	    r = DVC_MATCH; \
	  else \
	    r = DVC_LESS; \
	} \
      else \
	r = itc_compare_spec (it, buf, cl, sp);	\
    }

int64 dbe_key_count (dbe_key_t * key);




/* gate.c */


buffer_desc_t * page_fault (it_cursor_t * it, dp_addr_t dp);
#define PF_OF_DELETED ((buffer_desc_t*)-1L)
buffer_desc_t * page_fault_map_sem (it_cursor_t * it, dp_addr_t dp, int stay_inside);
#define PF_STAY_ATOMIC 1

#if defined (MTX_DEBUG) && !defined (PAGE_DEBUG)
#define PAGE_DEBUG
#endif

#ifdef PAGE_DEBUG
#define DBGP_NAME(nm) 		dbg_##nm
#define DBGP_PARAMS 		const char *file, int line,
#define DBGP_ARGS 		file, line,
#define DBGP_ARGS_0 		file, line
#define page_wait_access(itc,dp_to,buf_from,buf_ret,mode,max_change) \
	dbg_page_wait_access (__FILE__,__LINE__,itc,dp_to,buf_from,buf_ret,mode,max_change)
#define page_leave_inner(buf) \
        dbg_page_leave_inner (__FILE__,__LINE__,buf)
#define itc_down_transit(it,buf,to) dbg_itc_down_transit (__FILE__,__LINE__,it, buf, to)
#define itc_landed_down_transit(it,buf,to) dbg_itc_landed_down_transit (__FILE__,__LINE__,it, buf, to)
#define itc_reset(itc) dbg_itc_reset (__FILE__,__LINE__, (itc))
#else
#define DBGP_NAME(nm) 		nm
#define DBGP_PARAMS
#define DBGP_ARGS
#define DBGP_ARGS_0
#endif
buffer_desc_t * DBGP_NAME (itc_reset) (DBGP_PARAMS it_cursor_t * itc);
void DBGP_NAME (itc_down_transit) (DBGP_PARAMS it_cursor_t * it, buffer_desc_t ** buf, dp_addr_t to);
void DBGP_NAME (itc_landed_down_transit) (DBGP_PARAMS it_cursor_t * it, buffer_desc_t ** buf, dp_addr_t to);
void itc_dive_transit (it_cursor_t * it, buffer_desc_t ** buf, dp_addr_t to);
int DBGP_NAME (page_wait_access) (DBGP_PARAMS it_cursor_t * itc, dp_addr_t dp_to,
		  buffer_desc_t * buf_from,
		  buffer_desc_t ** buf_ret, int mode, int max_change);
void DBGP_NAME (page_leave_inner) (DBGP_PARAMS buffer_desc_t * buf);
void page_release_read (buffer_desc_t * buf);
void page_read_queue_add (buffer_desc_t * buf, it_cursor_t * itc);
void page_write_queue_add (buffer_desc_t * buf, it_cursor_t * itc);

void page_mark_change (buffer_desc_t * buf, int change);
buffer_desc_t * page_try_transit (it_cursor_t * it, buffer_desc_t * from,
				  dp_addr_t dp, int mode);
void it_wait_no_io_pending (void);

void page_leave_as_deleted (buffer_desc_t * buf);

/* void itc_page_leave (it_cursor_t *, buffer_desc_t * buf); */
#define itc_page_leave(it, buf) \
{ \
  ITC_IN_KNOWN_MAP ((it), (buf)->bd_page);			\
  if ((buf)->bd_page != (it)->itc_page) GPF_T1 ("itc_page_leave has different bd_page and itc_page"); \
  page_leave_inner ((buf));			\
  ITC_LEAVE_MAP_NC ((it));			\
}


#define page_leave_outside_map(buf) \
{ \
  it_map_t *itm = IT_DP_MAP ((buf)->bd_tree, (buf)->bd_page);	\
  mutex_enter (&itm->itm_mtx); \
  page_leave_inner (buf); \
  mutex_leave (&itm->itm_mtx); \
}


#define page_leave_outside_map_chg(buf, change)	\
{ \
  it_map_t *itm = IT_DP_MAP ((buf)->bd_tree, (buf)->bd_page);	\
  mutex_enter (&itm->itm_mtx); \
  page_mark_change (buf, change); \
  page_leave_inner (buf); \
  mutex_leave (&itm->itm_mtx); \
}


#define INSIDE_MAP 1
#define OUTSIDE_MAP 0

int virtuoso_sleep (long secs, long tms);
buffer_desc_t * itc_write_parent (it_cursor_t * itc,buffer_desc_t * buf);
void itc_set_parent_link (it_cursor_t * itc, dp_addr_t child_dp, dp_addr_t new_parent);
void  itc_root_cache_enter (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t leaf);
void itc_register (it_cursor_t * itc, buffer_desc_t * buf);
void itc_unregister (it_cursor_t * itc);
void itc_unregister_inner (it_cursor_t * itc, buffer_desc_t * buf, int is_transit);
void itc_unregister_while_on_page (it_cursor_t * it_in, it_cursor_t * preserve_itc, buffer_desc_t ** preserve_buf);


/* disk.c */

int word_free_bit (dp_addr_t w);
dbe_storage_t * dbs_allocate (char * name, char type);
void dbs_close (dbe_storage_t * dbs);
void wi_storage_offsets (void);
int dbs_open_disks (dbe_storage_t * dbs);
typedef dp_addr_t (* sort_key_func_t) (void *);

void dbs_page_allocated (dbe_storage_t * dbs, dp_addr_t n);
buffer_pool_t * bp_make_buffer_list (int n);
void buf_sort (buffer_desc_t ** bs, int n_bufs, sort_key_func_t _key);
dp_addr_t bd_phys_page_key (buffer_desc_t * b);
dp_addr_t bd_phys_page_key (buffer_desc_t * b);

typedef int (*sort_cmp_func_t)(int n1, int n2, void * cd);
void gen_qsort (int * in, int * left,
	   int n_in, int depth, sort_cmp_func_t cmp, void* cd);


int bp_buf_enter (buffer_desc_t * buf, it_map_t ** itm_ret);
buffer_desc_t * bp_get_buffer_1  (buffer_pool_t * bp, buffer_pool_t ** pool_for_action, int mode);
#define bp_get_buffer(bp, m) bp_get_buffer_1 (bp, NULL, m)
#define BP_BUF_REQUIRED 0
#define BP_BUF_IF_AVAIL 1
void  bp_delayed_stat_action (buffer_pool_t * bp);

void buf_touch (buffer_desc_t * buf, int in_bp);
void buf_untouch (buffer_desc_t * buf);
#define BUF_BACKDATE(buf) (buf->bd_timestamp = buf->bd_pool->bp_ts - 2 * buf->bd_pool->bp_n_bufs)
void buf_set_last (buffer_desc_t * buf);
void buf_recommend_reuse (buffer_desc_t * buf);

int buf_disk_read (buffer_desc_t * buf);
void buf_disk_write (buffer_desc_t * buf, dp_addr_t phy_dp_to);
disk_stripe_t * dp_disk_locate (dbe_storage_t * dbs, dp_addr_t target, OFF_T * place);

long dbs_count_pageset_items (dbe_storage_t * dbs, buffer_desc_t** ppage_set);
long dbs_count_free_pages (dbe_storage_t * dbs);
long dbs_count_incbackup_pages (dbe_storage_t * dbs);
long dbs_is_free_page (dbe_storage_t * dbs, dp_addr_t n);

void it_page_allocated (index_tree_t * it, dp_addr_t n);

void dbs_free_disk_page (dbe_storage_t * dbs, dp_addr_t dp);
buffer_desc_t * dbs_read_page_set (dbe_storage_t * dbs, dp_addr_t first_dp, int flag);
void bp_write_dirty (buffer_pool_t * bp, int force, int is_in_page_map, int n_oldest);

void dbs_sync_disks (dbe_storage_t * dbs);

extern int n_oldest_flushable;
#define OLD_DIRTY (main_bufs)
#define ALL_DIRTY 0
extern int main_bufs;
extern int checkpoint_in_progress;
extern int n_fds_per_file;


#define IN_LT_LOCKS(lt)  mutex_enter (&lt->lt_locks_mtx)
#define LEAVE_LT_LOCKS(lt)  mutex_leave (&lt->lt_locks_mtx)

void wi_open (char *mode);

void db_close (dbe_storage_t * dbs);
void wi_init_globals (void);


oid_t it_new_object_id (index_tree_t *);

extern void (*cfg_replace_log) (char * new_log);
void _cfg_replace_log (char * new_log);
extern void (*cfg_set_checkpoint_interval)(int32 f);
void _cfg_set_checkpoint_interval (int32 f);
extern int neodisk;
/* void dbs_write_free_set (dbe_storage_t * dbs, buffer_desc_t * buf); */
void dbs_write_page_set (dbe_storage_t * dbs, buffer_desc_t * buf);
void dbs_write_cfg_page (dbe_storage_t * dbs, int is_first);
void lt_wait_checkpoint (void);
void lt_wait_checkpoint_1 (int cl_listener_also);
void lt_wait_checkpoint_lt (lock_trx_t * lt);

/*
void dbs_locate_free_bit (dbe_storage_t * dbs, dp_addr_t near_dp,
		     uint32 **array, dp_addr_t *page_no, int *inx, int *bit);
*/

#define V_EXT_OFFSET_FREE_SET 0
#define V_EXT_OFFSET_INCB_SET 1
#define V_EXT_OFFSET_UNK_SET -1

#define dbs_locate_free_bit(dbs, near_dp, array, page_no, inx, bit) \
  dbs_locate_page_bit(dbs, &(dbs)->dbs_free_set, near_dp, array, page_no, inx, bit, V_EXT_OFFSET_FREE_SET, 1)
#define dbs_locate_incbackup_bit(dbs, near_dp, array, page_no, inx, bit) \
  dbs_locate_page_bit(dbs, &(dbs)->dbs_incbackup_set, near_dp, array, page_no, inx, bit, V_EXT_OFFSET_INCB_SET, 1)

int
dbs_locate_page_bit (dbe_storage_t* dbs, buffer_desc_t** free_set, dp_addr_t near_dp,
	uint32 **array, dp_addr_t *page_no, int *inx, int *bit, int offset, int assert_on_out_of_range);

void pg_init_new_root (buffer_desc_t * buf);
void itc_hold_pages (it_cursor_t * itc, buffer_desc_t * buf, int n);
void itc_free_hold (it_cursor_t * itc);
wi_db_t * wi_ctx_db (void);
dbe_storage_t * wd_storage (wi_db_t * wd, caddr_t name);
void it_not_in_any (du_thread_t * self, index_tree_t * except);

/* insert.c */
void map_resize (page_map_t ** pm_ret, int new_sz);
void map_insert_pos (page_map_t ** map_ret, int pos, int what);
void row_write_reserved (dtp_t * end, int n_bytes);

int str_cmp_2 (db_buf_t dv1, db_buf_t dv2, db_buf_t dv3, int l1, int l2, int l3, unsigned short offset);
row_size_t  row_length (db_buf_t row, dbe_key_t * key);
int  row_reserved_length (db_buf_t row, dbe_key_t * key);
void dbg_page_map (buffer_desc_t * buf);
void dbg_page_map_log (buffer_desc_t * buf, char * file, char * msg);
void dbg_page_map_f (buffer_desc_t * buf, FILE * out);
void pg_map_clear (buffer_desc_t * buf);
int pg_make_map (buffer_desc_t *);
void pg_check_map_1 (buffer_desc_t * buf);
int  pg_row_check (buffer_desc_t * buf, int irow, int gpf_on_err);

#if defined (PAGE_CHECK) | defined (PAGE_TRACE)

void pg_check_map (buffer_desc_t * buf);
#else
#define pg_check_map(buf)
#endif
int pg_room (db_buf_t page);

void page_write_gap (db_buf_t place, row_size_t len);
int map_entry_after (page_map_t * pm, int at);
void itc_insert_dv (it_cursor_t * it, buffer_desc_t ** buf, row_delta_t * rd,
		   int is_recursive, row_lock_t * new_rl);
#define INS_NEW_RL ((row_lock_t *) 1L)
#define INS_DOUBLE_LP ((row_lock_t*)2L)
void itc_make_exact_spec (it_cursor_t * it, db_buf_t thing);
int page_unlink_row (buffer_desc_t * buf, int pos, int * pos_after);
int itc_insert_unq_ck (it_cursor_t * it, row_delta_t * rd, buffer_desc_t ** unq_ret);
#define itc_insert(i,v) itc_insert_unq_ck (i, v, NULL)
#define UNQ_ALLOW_DUPLICATES ((buffer_desc_t **) -1L)  /* give as unq_buf to cause insert anyway */
#define UNQ_SORT ((buffer_desc_t **) -2L)  /* give as unq_buf to cause insert anyway */

db_buf_t strses_to_db_buf (dk_session_t * ses);
void itc_delete (it_cursor_t * it, buffer_desc_t ** buf_ret, int maybe_blobs);
int map_delete (page_map_t ** map_ret, int pos);
void dp_may_compact (dbe_storage_t *dbs, dp_addr_t);
void wi_check_all_compact (int age_limit);
extern dk_mutex_t * pl_ref_count_mtx;
extern dk_mutex_t * dbs_autocompact_mtx;
extern int dbs_autocompact_in_progress;
int  itc_vacuum_compact (it_cursor_t * itc, buffer_desc_t ** buf_ret);
void itc_fix_leaf_ptr (it_cursor_t * itc, buffer_desc_t * buf);
void pg_move_cursors (it_cursor_t ** temp_itc, int fill, buffer_desc_t * buf_from,
		 int from, dp_addr_t page_to, int to, buffer_desc_t * buf_to);

/* tree.c */


index_tree_t * it_allocate (dbe_storage_t *);
index_tree_t * it_temp_allocate (dbe_storage_t *);
void it_temp_free (index_tree_t * it);
int it_temp_tree (index_tree_t * it);
void it_free (index_tree_t * it);
#if !defined (__APPLE__)
void it_not_in_any (du_thread_t * self, index_tree_t * except);
#endif
extern buffer_desc_t * buffer_allocate (int type);
extern void buffer_free (buffer_desc_t * buf);
extern void buffer_set_free (buffer_desc_t* ps);
#ifdef MTX_DEBUG
int buf_set_dirty (buffer_desc_t * buf);
int buf_set_dirty_inside (buffer_desc_t * buf);
#else
#define buf_set_dirty(b)  ((b)->bd_is_dirty = 1)
#define buf_set_dirty_inside(b)  ((b)->bd_is_dirty = 1)
#endif

#define cl_enlist_ck(it)

void wi_new_dirty (buffer_desc_t * buf);


void dbe_key_open (dbe_key_t * key);
void key_dropped (dbe_key_t * key);
void dbe_key_save_roots (dbe_key_t * key);
void sch_save_roots (dbe_schema_t * sc);



/* space.h */


buffer_desc_t * itc_delta_this_buffer (it_cursor_t * itc, buffer_desc_t * buf, int stay_in_map);
#define DELTA_STAY_INSIDE 1
#define DELTA_MAY_LEAVE 0




dbe_schema_t * isp_schema_1 (void * thr);
#define isp_schema(x) (wi_inst.wi_schema)
buffer_desc_t * it_new_page (index_tree_t * isp, dp_addr_t nearxx, int type, int in_pmap, it_cursor_t * has_hold);
void it_free_page (index_tree_t * it, buffer_desc_t * buf);
void it_free_dp_no_read (index_tree_t * it, dp_addr_t dp, int dp_type);
void it_cache_check (index_tree_t * it, int mode);
#define IT_CHECK_ALL 0
#define IT_CHECK_FAST 1
#define IT_CHECK_POST 2


/* lock.c */

void lt_new_w_id (lock_trx_t * lt);
extern resource_t * idp_rc;
extern int32 swap_guard_on;


/* page.c */

int box_length_on_row (caddr_t val);
void pfh_init (pf_hash_t * pfh, buffer_desc_t * buf);
extern resource_t * pfh_rc;
pf_hash_t * pfh_allocate ();
void pfh_free (pf_hash_t * pfh);
short pfh_var (pf_hash_t * pfh, dbe_col_loc_t * cl, db_buf_t str, int len, unsigned short * prefix_bytes, unsigned short * prefix_ref, dtp_t * extra, int mode);
row_size_t  row_space_after (buffer_desc_t * buf, short irow);
void  pfh_set_int (pf_hash_t * pfh, int32 v, short nth_cl, short irow, short place);
void  pfh_set_int64 (pf_hash_t * pfh, int32 v, short nth_cl, short irow, short place);
void pfh_set_var (pf_hash_t * pfh, dbe_col_loc_t * cl, short irow, db_buf_t str, int len);
void pf_rd_append (page_fill_t * pf, row_delta_t * rd, row_size_t * split_after);

#define PAGE_WRITE_ORG 1
#define PAGE_WRITE_COPY 2
int page_prepare_write (buffer_desc_t * buf, db_buf_t * copy, int * copy_fill, int page_compress);

int page_col_cmp_1 (buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl, caddr_t value);
#define page_col_cmp(buf, row, cl, val) \
  (~DVC_NOORDER & page_col_cmp_1 (buf, row, cl, val))
void  page_row_bm (buffer_desc_t * buf, int irow, row_delta_t * rd, int op, it_cursor_t * bm_pl);
#define page_row(buf, irow, rd, op) page_row_bm (buf, irow, rd, op, NULL)
#define RO_LEAF 1
#define RO_ROW 2
#define RO_RB_ROW 3

#define LOCAL_RD(rd) \
    caddr_t rd##__vs[TB_MAX_COLS]; \
  row_delta_t rd;\
  memset (&rd, 0, sizeof (row_delta_t)); \
  rd.rd_values = rd##__vs; \
  rd.rd_allocated = RD_ALLOCATED_VALUES;


#define LOCAL_COPY_RD(rd) \
  caddr_t rd##__vs[TB_MAX_COLS]; \
  union { \
  void * dummy; \
  dtp_t rd##temp [2 * MAX_ROW_BYTES]; \
  } rd##temp_un; \
  row_delta_t rd;\
  memset (&rd, 0, sizeof (row_delta_t)); \
  rd.rd_temp = &(rd##temp_un.rd##temp[0]); \
  rd.rd_temp_max = sizeof (rd##temp_un.rd##temp); \
  rd.rd_values = rd##__vs; \
  rd.rd_allocated = RD_AUTO;



caddr_t rd_col (row_delta_t * rd, oid_t cid, int * found);
int key_col_in_layout_seq (dbe_key_t * key, dbe_column_t * col);
void kc_var_col (dbe_key_t * key, buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl, db_buf_t * p1, row_size_t * len1, db_buf_t * buf2, row_size_t* len2, unsigned short * offset);
void pf_fill_registered (page_fill_t * pf, buffer_desc_t * buf, it_cursor_t * itc);
int page_reloc_right_leaves (it_cursor_t * itc, buffer_desc_t * buf);
void pf_change_org (page_fill_t * pf);
void page_reg_past_end (buffer_desc_t * buf);

void page_apply (it_cursor_t * itc, buffer_desc_t * buf, int n_delta, row_delta_t ** delta, int op);
/* op for page_apply */
#define PA_MODIFY 0
#define PA_RELEASE_PL 1
#define PA_AUTOCOMPACT 2
#define PA_REWRITE_ONLY 4

void rd_free (row_delta_t * rd);
void rd_list_free (row_delta_t ** rds);


/* row.c */

caddr_t mp_box_iri_id (mem_pool_t * mp, iri_id_t iid);
void rd_free_box (row_delta_t * rd, caddr_t box);
void itc_delete_blob_search_pars (it_cursor_t * itc, row_delta_t * rd);
void row_insert_cast (row_delta_t * rd, dbe_col_loc_t * cl, caddr_t data,
		 caddr_t * err_ret, db_buf_t old_blob);
void row_insert_cast_temp (row_delta_t * rd, dbe_col_loc_t * cl, caddr_t data,
		 caddr_t * err_ret, db_buf_t old_blob);
void  itc_print_params (it_cursor_t * itc);
caddr_t itc_mp_box_column (it_cursor_t * itc, mem_pool_t * mp, buffer_desc_t *buf, oid_t col, dbe_col_loc_t * cl);
caddr_t page_mp_box_col (it_cursor_t * itc, mem_pool_t * mp, buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl);
caddr_t page_box_col (it_cursor_t * itc, buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl);
caddr_t page_copy_col (buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl, row_delta_t * rd);
void page_write_col (buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl, dk_session_t * ses, it_cursor_t * itc);

void row_set_col (row_fill_t * rf, dbe_col_loc_t * cl, caddr_t data);
void row_set_prefix (row_fill_t * rf, dbe_col_loc_t * cl, caddr_t value, row_size_t prefix_bytes, unsigned short prefix_ref, dtp_t extra);
dbe_col_loc_t * key_find_cl (dbe_key_t * key, oid_t col);
dbe_col_loc_t *cl_list_find (dbe_col_loc_t * cl, oid_t col_id);
search_spec_t * key_add_spec (search_spec_t * last, it_cursor_t * it,
			      dk_session_t * ses);

db_buf_t  itc_column (it_cursor_t * it, db_buf_t page, oid_t col_id);
caddr_t itc_box_row (it_cursor_t * it, buffer_desc_t * buf);

caddr_t itc_box_column (it_cursor_t * it, buffer_desc_t * buf, oid_t col, dbe_col_loc_t * cl);
long itc_long_column (it_cursor_t * it, buffer_desc_t * buf, oid_t col);
void key_free_trail_specs (search_spec_t * sp);
void itc_free_specs (it_cursor_t * it);
dbe_key_t * itc_get_row_key (it_cursor_t * it, buffer_desc_t * buf);

int itc_row_insert (it_cursor_t * it, row_delta_t * rd, buffer_desc_t ** unq_buf,
		    int blobs_in_place, int pk_only);

void itc_drop_index (it_cursor_t * it, dbe_key_t * key);

void itc_row_key_insert (it_cursor_t * it, db_buf_t row, dbe_key_t * ins_key);



/* meta.c */
const char * sch_skip_prefixes (const char *str);
int dtp_is_fixed (dtp_t dtp);
int dtp_is_var (dtp_t dtp);
void dk_set_append_1 (dk_set_t * res, void *item);
void dbe_key_free (dbe_key_t * key);
void dbe_key_layout (dbe_key_t * key, dbe_schema_t * sc);

/* redundant and incorrect: long strhash (char * strp); */

#if 0
void dd_print_key_id (dk_session_t * ses, key_id_t id);
#endif
dbe_schema_t * isp_read_schema (lock_trx_t * lt);
dbe_schema_t * isp_read_schema_1 (lock_trx_t * lt);
void isp_read_schema_2 (lock_trx_t * lt);

dbe_key_t *tb_name_to_key (dbe_table_t * tb, const char *name, int non_primary);

dbe_table_t * sch_name_to_table (dbe_schema_t * sc, const char * name);
void sch_normalize_new_table_case (dbe_schema_t * sc, char *q, size_t max_q, char *own, size_t max_own);
collation_t * sch_name_to_collation (char * name);
dbe_column_t *tb_name_to_column (dbe_table_t * tb, const char *name);
dbe_key_t * sch_id_to_key (dbe_schema_t * sc, key_id_t id);
dbe_column_t * sch_id_to_column (dbe_schema_t * sc, oid_t id);
int sch_is_subkey (dbe_schema_t* sc, key_id_t sub, key_id_t super);
int sch_is_subkey_incl (dbe_schema_t* sc, key_id_t sub, key_id_t super);
void sch_set_subkey (dbe_schema_t* sc, key_id_t sub, key_id_t super);
void sch_split_name (const char *q_default, const char *name, char *q, char *o, char *n);


dbe_key_t * sch_table_key (dbe_schema_t * sc, const char *table, const char *key, int non_primary);


struct query_s * sch_proc_def (dbe_schema_t * sch, const char * name);
struct query_s * sch_partial_proc_def (dbe_schema_t * sc, caddr_t name, char *q_def, char *o_def);
struct query_s * sch_proc_exact_def (dbe_schema_t * sch, const char * name);
struct query_s * sch_module_def (dbe_schema_t * sch, const char * name);
#define IS_REMOTE_ROUTINE_QR(qr) ((qr) && (qr)->qr_is_remote_proc)
void sch_set_proc_def (dbe_schema_t * sch, caddr_t name,  struct query_s * qr);
void sch_set_module_def (dbe_schema_t * sch, caddr_t name,  struct query_s * qr);
caddr_t numeric_from_x (numeric_t res, caddr_t x, int prec, int scale, char * col_name, oid_t cl_id, dbe_key_t *key);
void sch_drop_module_def (dbe_schema_t *sc, struct query_s *mod_qr);

void row_print_object (caddr_t thing, dk_session_t * ses, dbe_column_t * col, caddr_t * err_ret);
dk_set_t key_ensure_visible_parts (dbe_key_t * key);
void row_print_blob (it_cursor_t * itc, caddr_t thing, dk_session_t * ses, dbe_column_t * col,
    caddr_t * err_ret);

extern int case_mode;
#define CM_UPPER 1
#define CM_SENSITIVE 0
#define CM_MSSQL 2

#define CASEMODESTRCMP(s1, s2) (case_mode == CM_MSSQL ? stricmp((s1), (s2)) : strcmp((s1), (s2)))
#define CASEMODESTRNCMP(s1, s2, n) (case_mode == CM_MSSQL ? strnicmp((s1), (s2), (n)) : strncmp((s1), (s2), (n)))
/* outline versions for external apps */
int casemode_strcmp (const char *s1, const char *s2);
int casemode_strncmp (const char *s1, const char *s2, size_t n);

caddr_t DBG_NAME (sqlp_box_id_upcase) (DBG_PARAMS const char *str);
#ifdef MALLOC_DEBUG
#define sqlp_box_id_upcase(s) dbg_sqlp_box_id_upcase (__FILE__, __LINE__, s)
#endif
caddr_t t_sqlp_box_id_upcase (const char *str);
void sqlp_upcase (char *str);
caddr_t sqlp_box_upcase (const char *str);

extern int default_txn_isolation;
extern int min_iso_that_waits;
extern int null_unspecified_params;
extern int32 do_os_calls;
extern long max_static_cursor_rows;
extern long log_audit_trail;
extern long http_proxy_enabled;
#ifdef _IMSG
extern int pop3_port;
extern int nntp_port;
extern int ftp_port;
extern int ftp_server_timeout;
#endif
extern dk_set_t old_backup_dirs;
extern int enable_gzip;
extern int isdts_mode;
extern FILE *http_log;
extern char * http_soap_client_id_string;
extern char * http_client_id_string;
extern char * http_server_id_string;
extern long http_ses_trap;
extern unsigned long cfg_scheduler_period ;
extern long callstack_on_exception;
extern long pl_debug_all;
extern char * pl_debug_cov_file;
extern long vt_batch_size_limit;
extern long sqlc_add_views_qualifiers;
extern int sqlo_max_layouts;
extern int32 sqlo_max_mp_size;
extern long txn_after_image_limit;
extern long stripe_growth_ratio;
extern int disable_listen_on_unix_sock;
extern int disable_listen_on_tcp_sock;
extern unsigned long cfg_resources_clear_interval;
extern int sql_proc_use_recompile; /* from sqlcomp2.c */
extern int recursive_ft_usage; /* from meta.c */
extern int recursive_trigger_calls; /* from sqltrig.c */
extern long hi_end_memcache_size; /* hash.c */

extern int sqlc_no_remote_pk; /* from sqlstmts.c */
extern char *init_trace;
extern char *allowed_dirs;
extern char *denied_dirs;
extern char *backup_dirs;
extern char *safe_execs;
extern char *dba_execs;
extern char *www_root;
extern char *temp_dir;

/* Externals from virtuoso */
extern char *f_logfile;     /* only for persistent services */
extern char *f_config_file;   /* configuration file name */
extern char *f_license_file;   /* license file name */
extern int f_debug;
extern int f_read_from_rebuilt_database;
extern char *f_old_dba_pass, *f_new_dba_pass, *f_new_dav_pass;

#define MIN_CHECKPOINT_SIZE 2048
#define AUTOCHECKPOINT_SIZE 3072

extern unsigned long min_checkpoint_size;
extern unsigned long autocheckpoint_log_size; /* from sqlsrv.c */

extern char *default_mail_server;

void sch_set_view_def (dbe_schema_t * sc, char * name, caddr_t tree);
caddr_t sch_view_def (dbe_schema_t * sc, const char *name);
void dbe_schema_dead (dbe_schema_t * sc);
void it_free_schemas (index_tree_t * it, long now);
void srv_global_init (char *mode);
void db_to_log (void);
void db_crash_to_log (char *mode);

extern char *default_collation_name;
extern collation_t *default_collation;
extern caddr_t default_charset_name;
extern wcharset_t *default_charset;

extern caddr_t ws_default_charset_name;
extern wcharset_t *ws_default_charset;

extern char *http_port;
extern int32 http_threads;
extern int32 http_thread_sz;
extern int32 http_enable_client_cache;



/* ddlrun.c */

caddr_t it_read_object_dd (lock_trx_t * lt, dbe_schema_t * sc);
caddr_t it_read_object_schema (index_tree_t * it, lock_trx_t * lt,
			     dbe_schema_t * sp);
void ddl_ensure_stat_tables (void);

void sqlc_quote_dotted_quote (char *text, size_t tlen, int *fill, char *name, const char *quote);


/* log.c */

void log_replay_file (int fd);
void log_checkpoint (dbe_storage_t * dbs, char * new_file, int shutdown);
void log_delete (lock_trx_t * lt, row_delta_t * rd, int this_key_only);
int  log_check_trx (int64 trx_no);

void sf_fastdown (lock_trx_t * trx);
void sf_shutdown (char * log_name, lock_trx_t * lt);
void sf_makecp (char * log_name, lock_trx_t *trx, int fail_on_vdb, int shutdown);
void sf_make_auto_cp(void);
caddr_t log_new_name(char * log_name);
caddr_t sf_srv_status (void);
long sf_log (caddr_t * replicate);


/* mtwrite.c */

void buf_cancel_write (buffer_desc_t * buf);
void buf_release_read_waits (buffer_desc_t * buf, int itc_state);
void mt_write_start (int n_oldest);
void mt_write_init (void);
io_queue_t * db_io_queue (dbe_storage_t * dbs, dp_addr_t dp);
extern dk_mutex_t * mt_write_mtx;
extern int num_cont_pages;
void mt_write_dirty (buffer_pool_t * bp, int n_oldest, int phys_eq_log_only);
#define PHYS_EQ_LOG 1  /* only write pages that are not remapped. Used before checkpoint. */

void iq_schedule (buffer_desc_t ** bufs, int n);
void iq_shutdown (int mode);
#define IQ_SYNC 0
#define IQ_STOP 1
void iq_restart (void);
int iq_is_on (void);

extern int mti_writes_queued;
extern int mti_reads_queued;


/* blob.c */


#define BLOB_IN_INSERT 1
#define BLOB_IN_UPDATE 0
int itc_set_blob_col (it_cursor_t * row_itc, db_buf_t col,
    caddr_t data, blob_layout_t *replaced_version,
    int log_as_insert, sql_type_t *col_sqt);
blob_layout_t * bl_from_dv_it (dtp_t * col, index_tree_t * it);
#define bl_from_dv(d, i) bl_from_dv_it (d, i->itc_tree)

blob_handle_t * bh_from_dv (dtp_t * col, it_cursor_t * itc);
void bh_to_dv (blob_handle_t * bh, dtp_t * col, dtp_t dtp);
int  blob_check (blob_handle_t * bh);
int  bl_check (blob_layout_t * bl);
#define BLOB_OK 0
#define BLOB_FREE 1

#define IS_INLINEABLE_DTP(dtp)  (DV_BLOB == (dtp) || DV_BLOB_BIN == (dtp))


#ifdef BL_DEBUG
extern void dbg_blob_layout_free (const char *file, int line, blob_layout_t * bl);
#define blob_layout_free(b) dbg_blob_layout_free (__FILE__, __LINE__, b)
#else
extern void blob_layout_free (blob_layout_t * bl);
#endif

box_t blob_layout_ctor (dtp_t blob_handle_dtp, dp_addr_t start, dp_addr_t dir_start, int64 length, int64 diskbytes, index_tree_t * it);
int blob_read_dir (it_cursor_t * itc, dp_addr_t ** pages, int * is_complete, dp_addr_t dir_start, dk_set_t * dir_page_ret);
box_t blob_layout_from_handle_ctor (blob_handle_t *bh);
int itc_print_blob_col_non_txn (it_cursor_t * row_itc, dk_session_t * row, caddr_t data, int is_extension);
int bh_fill_buffer_from_blob (index_tree_t * it, lock_trx_t * lt, blob_handle_t * bh,
    caddr_t outbuf, long get_bytes);
void blob_chain_delete (it_cursor_t * it, blob_layout_t *bl);
void blob_send_bytes (lock_trx_t * lt, caddr_t bh, long n_bytes, int send_position, long blob_type);
void lt_write_blob_log (lock_trx_t * lt, dk_session_t * log_ses);
dk_session_t * blob_to_string_output_isp (lock_trx_t * lt, caddr_t bhp);
typedef struct blob_log_s
{
  dp_addr_t bl_start;
  dp_addr_t bl_dir_start;
  long bl_diskbytes;
  dtp_t bl_blob_dtp;
  oid_t bl_col_id;
  char * bl_table_name;
  index_tree_t *	bl_it;
} blob_log_t;

int blob_write_log (lock_trx_t * lt, dk_session_t * log, blob_log_t * bl);
void blob_log_replace (it_cursor_t * it, blob_layout_t * bl);

void rd_fixup_blob_refs (it_cursor_t * itc, row_delta_t * rd);
caddr_t blob_to_string_it (lock_trx_t * lt, index_tree_t *it, caddr_t bhp);
caddr_t blob_to_string (lock_trx_t * lt, caddr_t bhp);
caddr_t safe_blob_to_string (lock_trx_t * lt, caddr_t bhp, caddr_t *err);
dk_session_t *blob_to_string_output_it (lock_trx_t * lt, index_tree_t *it, caddr_t bhp);
dk_session_t *blob_to_string_output (lock_trx_t * lt, caddr_t bhp);
dk_session_t *bloblike_pages_to_string_output (dbe_storage_t * dbs, lock_trx_t * lt, dp_addr_t start, int * error);
caddr_t blob_subseq (lock_trx_t * lt, caddr_t bhp, size_t from, size_t to );
long bh_write_out (lock_trx_t * lt, blob_handle_t * bh, dk_session_t *ses);
void blob_log_write (it_cursor_t * it, dp_addr_t start, dtp_t blob_handle_dtp, dp_addr_t dir_start, int64 diskbytes,
		     oid_t col_id, char * tb_name);
void blob_log_set_free (s_node_t *set);
int blob_log_set_delete (dk_set_t * set, dp_addr_t dp);
int bh_fetch_dir (lock_trx_t * lt, blob_handle_t * bh);

#define BLOB_CHANGED 1
#define BLOB_NO_CHANGE 0


/*int wide_blob_buffered_read (dk_session_t * ses_from, char* to, int req_chars, blob_state_t * state, int * page_end); now static in blob.c*/

/* Low-level read or write of a blob page, e.g., for random access */
extern int page_wait_blob_access (it_cursor_t * itc, dp_addr_t dp_to, buffer_desc_t ** buf_ret, int mode, blob_handle_t *bh, int itc_map_wrap);


/* neodisk.c */

#define lt_weird() lt_note (__FILE__, __LINE__);
void lt_note (char * file, int line);
void  dbs_cpt_recov (dbe_storage_t * dbs);
void dbs_recov_write_page_set (dbe_storage_t * dbs, buffer_desc_t * buf);
void cpt_ins_image (buffer_desc_t * buf, int map_pos);
void cpt_upd_image (buffer_desc_t * buf, int map_pos);
void page_lock_to_row_locks (buffer_desc_t * buf);
void cpt_rollback (int may_freeze);
void cpt_over (void);
void dbs_checkpoint (char * log_name, int shutdown);
#define CPT_NORMAL 0
#define CPT_SHUTDOWN 1
#define CPT_INC_RESET 2
#define CPT_DB_TO_LOG 3
void dbs_read_checkpoint_remap (dbe_storage_t * dbs, dp_addr_t from);
int it_can_reuse_logical (index_tree_t * it, dp_addr_t dp);

void it_free_remap (index_tree_t * it, dp_addr_t logical, dp_addr_t remap, int dp_flags);

#define DP_CHECKPOINT_REMAP(dbs, dp)\
  ((dp_addr_t)(ptrlong)gethash (DP_ADDR2VOID (dp), dbs->dbs_cpt_remap))
#define ISP_DP_TO_BUF(isp, dp) ((buffer_desc_t *) gethash (DP_ADDR2VOID (dp), isp -> isp_dp_to_buf))
int cpt_count_mapped_back (dbe_storage_t * dbs);
dp_addr_t remap_phys_key (remap_t * r);
int cpt_is_global_lock (void);


/* other */

void sqlo_box_print (caddr_t tree);
/* acc.c */




/* registry, sequences */

#define SEQUENCE_GET 2
#define SET_IF_GREATER 1
#define SET_ALWAYS 0


#define SEQ_MAX_CHARS 300

void dbs_registry_set (dbe_storage_t * dbs, const char *name, const char *value, int is_boxed);
void dbs_registry_from_array (dbe_storage_t * dbs, caddr_t * reg);
caddr_t * dbs_registry_to_array (dbe_storage_t * dbs);
void registry_exec (void);
boxint sequence_set_1 (char * name, boxint value, int mode, int in_map, caddr_t * err_ret);
boxint sequence_next (char * name, int in_map);
boxint sequence_next_inc_1 (char *name, int in_map, boxint inc_by, caddr_t * err_ret);
int sequence_remove (char *name, int in_map);
box_t sequence_get_all ( void ); /* returns the name,value, name,value array */
#define sequence_set(name,value,mode,in_map) sequence_set_1(name,value,mode,in_map, NULL)
#define sequence_next_inc(name,in_map,inc_by) sequence_next_inc_1(name,in_map,inc_by, NULL)

EXE_EXPORT(caddr_t, registry_get, (const char *name));
void registry_set_1 (const char * name, const char * value, int is_boxed, caddr_t * err_ret);
#define registry_set(name,value) registry_set_1(name,value,0, NULL)
EXE_EXPORT(box_t, registry_get_all, ( void )); /* returns the name,value, name,value array */
caddr_t registry_remove (char *name);

int dbs_write_registry (dbe_storage_t * dbs);
void dbs_init_registry (dbe_storage_t * dbs);
void db_replay_registry_sequences (void);
void cli_bootstrap_cli ();
void db_log_registry (dk_session_t * log);
void registry_update_sequences (void);
caddr_t box_deserialize_string (caddr_t text, int opt_len, short offset);
caddr_t mp_box_deserialize_string (mem_pool_t * mp, caddr_t text, int opt_len, short offset);


/* sqlsrv.c */
void itc_flush_client (it_cursor_t * itc);
extern unsigned long autocheckpoint_log_size;
caddr_t  sf_make_new_log_name(dbe_storage_t * dbs);
extern int threads_is_fiber;
void srv_plugins_init (void);

/* sqlpfn.c */
caddr_t list (long n, ...);
caddr_t sc_list (long n, ...);

/* blob.c */

/* These functions updates blob's layout information in transaction's hashtable
   of dirty buffers and controls whether this blob should be deleted at
   commit and/or rollback time. \c add_jobs and \c cancel_jobs are bitmasks
   of BL_DELETE_AT_XXX bits to be set or cleared in layout's bl_delete_later
   */
void blob_schedule_delayed_delete (it_cursor_t * itc, blob_layout_t *bl, int add_jobs);
void blob_cancel_delayed_delete (it_cursor_t * itc, dp_addr_t first_blob_page, int cancel_jobs);

/* gate.c */
int itc_try_land (it_cursor_t * itc, buffer_desc_t ** buf_ret);
int itc_up_transit (it_cursor_t * itc, buffer_desc_t ** buf_ret);
void it_unregister_all (index_tree_t * isp);
void it_root_image_invalidate (index_tree_t * tree);


/* disk.c */
int dbs_seg_extend (dbe_storage_t * dbs, int n);
OFF_T dbs_extend_stripes (dbe_storage_t * dbs);


/* auxfiles.c */
dbe_storage_t *dbs_from_file (char * name, char * file, char type, volatile int * exists);
void _dbs_read_cfg (dbe_storage_t * dbs, char *file);
extern void (*dbs_read_cfg) (caddr_t * dbs, char *file);
dk_set_t _cfg_read_storages (caddr_t **temp_storage);
extern dk_set_t (*dbs_read_storages) (caddr_t **temp_file);
extern int freeing_unfreeable;
caddr_t dbs_log_derived_name (dbe_storage_t * dbs, char * ext);
void dbs_unfreeable (dbe_storage_t * dbs, dp_addr_t dp, int flag);
void page_set_check (db_buf_t page);

#ifndef NDEBUG
#define PAGE_SET_CHECKSUM
#endif
#ifdef PAGE_SET_CHECKSUM
extern void page_set_update_checksum (uint32 * page, int inx, int bit);
extern void page_set_checksum_init (db_buf_t page);
#else
#define page_set_update_checksum(a,i,b)
#define page_set_checksum_init(a)
#define page_set_check(p)
#endif





/* hash.c */
#define HC_INIT 0xa5c33a59
#ifdef NEW_HASH
void itc_hi_source_page_used (it_cursor_t * itc, dp_addr_t dp);
#endif
void hi_free (hash_index_t * hi);
void hic_clear (void);
void  it_hi_invalidate (index_tree_t * it, int in_hic);
/* bif_repl.c */
extern unsigned long cfg_scheduler_period;
extern unsigned long main_continuation_reason;
#define MAIN_CONTINUE_ON_CHECKPOINT	0
#define MAIN_CONTINUE_ON_SCHEDULER	1
void sched_do_round (void);
void sched_run_at_start (void);
void sched_do_round_1 (const char * text);
void sched_set_thread_count (void);

caddr_t box_cast_to (caddr_t *qst, caddr_t data, dtp_t data_dtp,
    dtp_t to_dtp, ptrlong prec, unsigned char scale, caddr_t *err_ret);

caddr_t box_sprintf_escaped (caddr_t str, int is_id);

void dp_set_backup_flag (dbe_storage_t * dbs, dp_addr_t page, int on);
int dp_backup_flag (dbe_storage_t * dbs, dp_addr_t page);

void hosting_plugin_init (void);
void plugin_loader_init(void);

/* rdfinf.c */
void sas_ensure (void);
/* trans.c */
extern int32 tn_cache_enable;
/*  rdfbox.c */
void print_short (short s, dk_session_t * ses);

extern rdf_box_t * rb_allocate (void);
extern int dv_rdf_compare (db_buf_t dv1, db_buf_t dv2);
extern int rdf_box_compare (ccaddr_t rb1, ccaddr_t rb2);
/*rdf_core.c */
int  iri_split (char * iri, caddr_t * pref, caddr_t * name);

typedef struct name_id_cache_s
{
  dk_mutex_t *	nic_mtx;
  dk_hash_64_t *	nic_id_to_name;
  id_hash_t *	nic_name_to_id;
  unsigned long	nic_size;
} name_id_cache_t;

extern name_id_cache_t * iri_name_cache;
extern name_id_cache_t * iri_prefix_cache;
extern name_id_cache_t * rdf_lang_cache;
extern name_id_cache_t * rdf_type_cache;
boxint nic_name_id (name_id_cache_t * nic, char * name);
caddr_t DBG_NAME(nic_id_name) (DBG_PARAMS name_id_cache_t * nic, boxint id);
#ifdef MALLOC_DEBUG
#define nic_id_name(nic,id) DBG_NAME(nic_id_name) (__FILE__, __LINE__, (nic), (id))
#endif
void nic_set (name_id_cache_t * nic, caddr_t name, boxint id);
boxint  lt_nic_name_id (lock_trx_t * lt, name_id_cache_t * nic, caddr_t name);
caddr_t  lt_nic_id_name (lock_trx_t * lt, name_id_cache_t * nic, boxint id);
void lt_nic_set (lock_trx_t * lt, name_id_cache_t * nic, caddr_t name, boxint id);



/* bif_file.c */
void init_file_acl_set (char *acl_string1, dk_set_t * acl_set_ptr);
void init_server_cwd (void);
char *virt_strerror (int eno);



#define BYTE_ORDER_REV_SUPPORT

extern int dbs_reverse_db; /* global flag, indicates reverse order of database */
extern int dbs_cpt_recov_in_progress; /* cpt recovery in progress */
extern int dbs_stop_cp;
extern void dbs_write_reverse_db (dbe_storage_t * dbs);

extern int32 cf_lock_in_mem;
extern int space_rehash_threshold;
extern int mt_write_pending;
extern long bp_last_pages;

extern int correct_parent_links;
extern long file_extend;
extern int32 c_checkpoint_sync;
extern void (*db_read_cfg) (caddr_t * dbs, char *mode);
extern dk_mutex_t *time_mtx;
extern dk_mutex_t * old_roots_mtx;
extern buffer_desc_t * old_root_images;
extern int prefix_in_result_col_names;
extern int is_crash_dump;
extern int32 cpt_remap_recovery;

extern void (*db_exit_hook) (void);
extern long last_flush_time;
extern long last_exec_time;	/* used to know when the system is idle */

extern unsigned long int cfg_autocheckpoint;	/* Defined in disk.c */
extern int32 c_checkpoint_interval;
extern dk_mutex_t * checkpoint_mtx;
extern int32 cl_run_local_only;
#define CL_RUN_CLUSTER		0	/*!< Normal work of the cluster */
#define CL_RUN_LOCAL		1	/*!< Normal work of single box */
#define CL_RUN_SINGLE_CLUSTER	2	/*!< Cluster is configured but connections are not yet established */

extern int cluster_enable;
extern unsigned long int cfg_thread_live_period;
extern unsigned long int cfg_thread_threshold;
extern du_thread_t *the_main_thread;	/* Set in srv_global_init in sqlsrv.c */
extern semaphore_t *background_sem;
extern int main_thread_ready;
extern void resources_reaper (void);
extern int auto_cpt_scheduled;

extern long write_cum_time;
extern int is_read_pending;
extern int32 bp_n_bps;

extern int cp_unremap_quota;
extern dp_addr_t crashdump_start_dp;
extern dp_addr_t crashdump_end_dp;
extern int sqlc_hook_enable;
extern int cfg_setup (void);
extern char *repl_server_enable;
extern long repl_queue_max;
extern int dive_cache_enable;

extern int default_txn_isolation;
extern int c_use_aio;
extern int c_stripe_unit;
extern long dbev_enable; /* from sqlsrv.c */
extern int in_srv_global_init;
extern long vd_param_batch;
extern long cfg_disable_vdb_stat_refresh;

#define VD_ARRAY_PARAMS_NONE 0
#define VD_ARRAY_PARAMS_DML  1
#define VD_ARRAY_PARAMS_ALL  2

extern long vd_opt_arrayparams;
extern unsigned long checkpointed_last_time;
extern long vsp_in_dav_enabled;

extern int disk_no_mt_write;

extern unsigned ptrlong initbrk;

extern long srv_pid;

extern id_hash_t * registry;
extern id_hash_t *sequences;

extern long http_print_warnings_in_output;
typedef enum { SQW_OFF, SQW_ON, SQW_ERROR } sqw_mode;
extern sqw_mode sql_warning_mode;
extern long sql_warnings_to_syslog;
extern long temp_db_size;

void
srv_set_cfg(
    void (*replace_log)(char *str),
    void (*set_checkpoint_interval)(int32 f),
    void (*read_cfg)(caddr_t * it, char *mode),
    void (*s_read_cfg)(caddr_t * it, char *mode),
    dk_set_t (*read_storages)(caddr_t **temp_file)
    );

void db_recover_keys (char *keys);
int http_init_part_one (void);
int http_init_part_two (void);

extern long server_port;
extern unsigned blob_page_dir_threshold;
extern int virtuoso_server_initialized;
extern int dive_pa_mode;
extern unsigned int bp_hit_ctr;
extern int32 c_compress_mode;
extern int rdf_no_string_inline;
/* geo.c */


/* extent.c */

void em_free_mem (extent_map_t * em);
extent_map_t * dbs_read_extent_map (dbe_storage_t * dbs, char * name, dp_addr_t dp);
extent_map_t *  dbs_dp_to_em (dbe_storage_t * dbs, dp_addr_t dp);
void dbs_cpt_extents (dbe_storage_t * dbs, dk_set_t free_trees);
void dbs_cpt_recov_write_extents (dbe_storage_t * dbs);
int buf_ext_check (buffer_desc_t * buf);
void  kf_set_extent_map (dbe_key_frag_t * kf);
void dbs_extent_open (dbe_storage_t * dbs);
void dbs_extent_init (dbe_storage_t * dbs);
void em_dp_allocated (extent_map_t * em, dp_addr_t dp, int is_temp);
void em_free_dp (extent_map_t * em, dp_addr_t dp, int is_temp_free);
dp_addr_t em_new_dp (extent_map_t * em, int type, dp_addr_t near, int * hold);
void em_free_remap_hold (extent_map_t * em, int * hold);
int em_hold_remap (extent_map_t * em, int * hold);
int it_own_extent_map (index_tree_t * tree);
void dbs_cpt_write_extents (dbe_storage_t * dbs);
void em_check_dp (extent_map_t * em, dp_addr_t dp);
void em_free (extent_map_t * em);
void dbs_cpt_set_allocated (dbe_storage_t * dbs, dp_addr_t dp, int is_allocd);
void clear_old_root_images  ();

extern dk_mutex_t * extent_map_create_mtx;

#define WAIT_IF(msec) if (msec) virtuoso_sleep ((msec) /1000, 1000 * ((msec) % 1000));
extern int32 sql_const_cond_opt;
extern int aq_max_threads;
extern int in_log_replay;
extern int32 dbs_check_extent_free_pages;
#ifndef NDEBUG
void ws_lt_trace (lock_trx_t * lt);
#endif

extern int32 em_ra_window;
extern int32 em_ra_threshold;
extern int32 em_ra_startup_window;
extern int32 em_ra_startup_threshold;

#endif /* _WIFN_H */
