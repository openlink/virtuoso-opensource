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
 *  
*/

#ifndef _WIFN_H
#define _WIFN_H

#include "wi.h"
#include "widisk.h"
#include "widd.h"
#include "schspace.h"

/* search.c */

void const_length_init (void);
void db_buf_length  (unsigned char * buf, long * head_ret, long * len_ret);
int box_serial_length (caddr_t box, dtp_t dtp);
extern short db_buf_const_length [256];

int  dv_composite_cmp (db_buf_t dv1, db_buf_t dv2, collation_t * coll);
int dv_compare (db_buf_t dv1, db_buf_t dv2, collation_t *collation);
int dv_compare_box (db_buf_t dv1, caddr_t box, collation_t *collation);
int pg_key_compare (buffer_desc_t * buf, int pos, it_cursor_t * it);
int itc_col_check (it_cursor_t * itc, search_spec_t * spec, int param_inx);
int itc_like_compare (it_cursor_t * itc, caddr_t pattern, search_spec_t * spec);


#ifdef MALLOC_DEBUG
it_cursor_t * dbg_itc_create (const char *file, int line, void *, lock_trx_t *);
#define itc_create(a,b)  dbg_itc_create (__FILE__, __LINE__, a, b)
#else
it_cursor_t * itc_create (void *, lock_trx_t *);
#endif
void itc_free (it_cursor_t *);
void itc_clear (it_cursor_t * it);
void itc_free_owned_params (it_cursor_t * itc);
buffer_desc_t * itc_reset (it_cursor_t * itc);
int dv_compare (db_buf_t dv1, db_buf_t dv2, collation_t *collation);
int dv_compare_spec (db_buf_t db, search_spec_t * spec, it_cursor_t * it);
dp_addr_t leaf_pointer (db_buf_t page, int pos);
int pg_gap_length (db_buf_t page, int pos);
buffer_desc_t * page_reenter_excl (it_cursor_t * it);
int find_leaf_pointer (buffer_desc_t * buf, dp_addr_t lf, it_cursor_t * it, int * map_pos);
int pg_skip_gap (db_buf_t page, int pos);
void itc_skip_entry (it_cursor_t * it, db_buf_t page);
void itc_prev_entry (it_cursor_t * it, buffer_desc_t * buf);

void itc_down_transit (it_cursor_t * it, buffer_desc_t ** buf, dp_addr_t to);

#define PS_LOCKS 0
#define PS_NO_LOCKS 1
#define PS_OWNED 2

int itc_search (it_cursor_t * it, buffer_desc_t ** buf_ret);
void itc_restart_search (it_cursor_t * it, buffer_desc_t ** buf);

int itc_page_search (it_cursor_t * it, buffer_desc_t ** buf_ret,
		     dp_addr_t * leaf_ret);
int itc_page_insert_search (it_cursor_t * it, buffer_desc_t * buf,
			dp_addr_t * leaf_ret);

int itc_page_split_search (it_cursor_t * it, buffer_desc_t * buf,
		       dp_addr_t * leaf_ret);


void itc_from (it_cursor_t * it, dbe_key_t * key);
void itc_clear_stats (it_cursor_t *it);
void itc_from_keep_params (it_cursor_t * it, dbe_key_t * key);
void itc_from_it (it_cursor_t * itc, index_tree_t * it);
int itc_next (it_cursor_t * it, buffer_desc_t ** buf_ret);
int64 itc_sample (it_cursor_t * it, buffer_desc_t ** buf_ret);
unsigned int64 key_count_estimate (dbe_key_t * key, int n_samples, int upd_col_stats);
caddr_t key_name_to_iri_id (lock_trx_t * lt, caddr_t name, int make_new);
int  key_rdf_lang_id (caddr_t name);

void plh_free (placeholder_t * pl);
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
void itc_read_ahead_blob (it_cursor_t * itc, struct ra_req_s *ra);
void itc_read_ahead (it_cursor_t * itc, buffer_desc_t ** buf_ret);

#define DV_COMPARE_SPEC(r, sp, it) \
  if (sp->sp_min_op == CMP_EQ) \
    { \
      r = itc_col_check (it, sp, sp->sp_min); \
    } \
  else \
    r = itc_compare_spec (it, sp);

#define DV_COMPARE_SPEC_W_NULL(r, sp, it) \
  if (sp->sp_min_op == CMP_EQ) \
    { \
      r = itc_col_check (it, sp, sp->sp_min); \
    } \
  else \
    { \
      if (sp->sp_cl.cl_null_mask & (sp->sp_cl.cl_null_mask & it->itc_row_data[sp->sp_cl.cl_null_flag])) \
	{ \
	  if ((sp->sp_max_op != CMP_NONE && it->itc_search_param_null[sp->sp_max]) \
	   || (sp->sp_min_op != CMP_NONE && it->itc_search_param_null[sp->sp_min])) \
	    r = DVC_MATCH; \
	  else \
	    r = DVC_LESS; \
	} \
      else \
	r = itc_compare_spec (it, sp); \
    }





/* gate.c */


buffer_desc_t * page_fault (it_cursor_t * it, dp_addr_t dp);
#define PF_OF_DELETED ((buffer_desc_t*)-1L)
buffer_desc_t * page_fault_map_sem (it_cursor_t * it, dp_addr_t dp, int stay_inside);
#define PF_STAY_ATOMIC 1

int page_wait_access (it_cursor_t * itc, dp_addr_t dp_to, buffer_desc_t * buf_to,
		  buffer_desc_t * buf_from,
		  buffer_desc_t ** buf_ret, int mode, int max_change);
void page_mark_change (buffer_desc_t * buf, int change);
buffer_desc_t * page_try_transit (it_cursor_t * it, buffer_desc_t * from,
				  dp_addr_t dp, int mode);
void it_wait_no_io_pending (void);

void page_leave_inner (buffer_desc_t * buf);
void itc_page_leave (it_cursor_t *, buffer_desc_t * buf);

int page_get_write (it_cursor_t * it, buffer_desc_t * buf);
int page_get_write_express (it_cursor_t * it, buffer_desc_t * buf);

void itc_register_back_position (it_cursor_t * it, buffer_desc_t * buf);
void itc_remove_back_position (it_cursor_t * it);
void itc_bust_back_positions (index_space_t * isp, dp_addr_t dp);

void itc_register_cursor (it_cursor_t * it, int is_in_pmap);

#define INSIDE_MAP 1
#define OUTSIDE_MAP 0

void itc_register_lock_wait (it_cursor_t * it);
void itc_unregister (it_cursor_t * it, int is_in_pmap);

int itc_write_transit (it_cursor_t * it, buffer_desc_t ** buf_ret, int is_excl);
/* whether the write is exclusive in isp. used w/ itc_write_transit */
#define WT_EXCL 1
#define WT_NON_EXCL 0
void itc_leave_write (it_cursor_t * it);
void isp_free_write_waits (index_space_t * isp);


int page_transit (it_cursor_t * it,
		  dp_addr_t to, buffer_desc_t ** buf_ret);



/* disk.c */

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

buffer_desc_t * bp_get_buffer  (buffer_pool_t * bp, int mode);
#define BP_BUF_REQUIRED 0
#define BP_BUF_IF_AVAIL 1
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

dp_addr_t dbs_get_free_disk_page (dbe_storage_t * dbs, dp_addr_t nearxx);
void dbs_free_disk_page (dbe_storage_t * dbs, dp_addr_t dp);

void bp_write_dirty (buffer_pool_t * bp, int force, int is_in_page_map, int n_oldest);

void dbs_sync_disks (dbe_storage_t * dbs);

extern int n_oldest_flushable;
#define OLD_DIRTY (main_bufs)
#define ALL_DIRTY 0
extern int main_bufs;
extern int checkpoint_in_progress;
extern int n_fds_per_file;
extern dk_mutex_t * lt_locks_mtx;


#define IN_LT_LOCKS  mutex_enter (lt_locks_mtx)
#define LEAVE_LT_LOCKS  mutex_leave (lt_locks_mtx)

void wi_open (char *mode);

void db_close (dbe_storage_t * dbs);
void fc_init (free_set_cache_t * fc);
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

/*
void dbs_locate_free_bit (dbe_storage_t * dbs, dp_addr_t near_dp,
		     uint32 **array, dp_addr_t *page_no, int *inx, int *bit);
*/

#define V_EXT_OFFSET_FREE_SET 0
#define V_EXT_OFFSET_INCB_SET 1
#define V_EXT_OFFSET_UNK_SET -1

#define dbs_locate_free_bit(dbs, near_dp, array, page_no, inx, bit) \
  dbs_locate_page_bit(dbs, &(dbs)->dbs_free_set, near_dp, array, page_no, inx, bit, V_EXT_OFFSET_FREE_SET)
#define dbs_locate_incbackup_bit(dbs, near_dp, array, page_no, inx, bit) \
  dbs_locate_page_bit(dbs, &(dbs)->dbs_incbackup_set, near_dp, array, page_no, inx, bit, V_EXT_OFFSET_INCB_SET)

void
dbs_locate_page_bit (dbe_storage_t* dbs, buffer_desc_t** free_set, dp_addr_t near_dp,
	uint32 **array, dp_addr_t *page_no, int *inx, int *bit, int offset);

void pg_init_new_root (buffer_desc_t * buf);
void itc_hold_pages (it_cursor_t * itc, buffer_desc_t * buf, int n);
void itc_free_hold (it_cursor_t * itc);
wi_db_t * wi_ctx_db (void);
dbe_storage_t * wd_storage (wi_db_t * wd, caddr_t name);

/* insert.c */

void row_write_reserved (dtp_t * end, int n_bytes);

int  row_length (db_buf_t row, dbe_key_t * key);
int  row_reserved_length (db_buf_t row, dbe_key_t * key);
void dbg_page_map (buffer_desc_t * buf);
void pg_map_clear (buffer_desc_t * buf);
int pg_make_map (buffer_desc_t *);
#if defined (MTX_DEBUG) | defined (PAGE_TRACE)

void pg_check_map (buffer_desc_t * buf);
#else
#define pg_check_map(buf)
#endif
int pg_room (db_buf_t page);

void pg_write_gap (db_buf_t place, int len);
int map_entry_after (page_map_t * pm, int at);
int itc_insert_dv (it_cursor_t * it, buffer_desc_t ** buf, db_buf_t dv,
		   int is_recursive, row_lock_t * new_rl);
#define INS_NEW_RL ((row_lock_t *) 1L)
void itc_make_exact_spec (it_cursor_t * it, db_buf_t thing);

int itc_insert_unq_ck (it_cursor_t * it, db_buf_t thing, buffer_desc_t ** unq_ret);
#define itc_insert(i,v) itc_insert_unq_ck (i, v, NULL)
#define UNQ_ALLOW_DUPLICATES ((buffer_desc_t **) -1L)  /* give as unq_buf to cause insert anyway */
#define UNQ_SORT ((buffer_desc_t **) -2L)  /* give as unq_buf to cause insert anyway */

db_buf_t strses_to_db_buf (dk_session_t * ses);
void itc_delete (it_cursor_t * it, buffer_desc_t ** buf_ret, int maybe_blobs);
int itc_commit_delete (it_cursor_t * it, buffer_desc_t ** buf_ret);
void itc_immediate_delete_blobs (it_cursor_t * it, buffer_desc_t *buf);

int map_delete (page_map_t ** map_ret, int pos);
void pg_delete_move_cursors (it_cursor_t * itc, dp_addr_t dp_from,
			     int from,
			     dp_addr_t page_to, int to,
			     buffer_desc_t * buf_to);
void dp_may_compact (dbe_storage_t *dbs, dp_addr_t);
void wi_check_all_compact (int age_limit);
void  itc_vacuum_compact (it_cursor_t * itc, buffer_desc_t * buf);


/* tree.c */


index_tree_t * it_allocate (dbe_storage_t *);
index_tree_t * it_temp_allocate (dbe_storage_t *);
void it_temp_free (index_tree_t * it);
void it_temp_tree (index_tree_t * it);
#if !defined (__APPLE__)
void it_not_in_any (du_thread_t * self, index_tree_t * except);
#endif
extern buffer_desc_t * buffer_allocate (int type);
extern void buffer_free (buffer_desc_t * buf);
extern void buffer_set_free (buffer_desc_t* ps);
int buf_set_dirty (buffer_desc_t * buf);
int buf_set_dirty_inside (buffer_desc_t * buf);
void wi_new_dirty (buffer_desc_t * buf);


void dbe_key_open (dbe_key_t * key);
void key_dropped (dbe_key_t * key);
void dbe_key_save_roots (dbe_key_t * key);
void sch_save_roots (dbe_schema_t * sc);



/* space.h */

#if 0
void isp_clear (index_space_t * isp);
#endif
index_space_t * isp_allocate (index_tree_t * it, int hash_sz);
const char * isp_title (index_space_t * isp);

void  isp_free (index_space_t * isp);

buffer_desc_t * isp_locate_page (index_space_t * isp, dp_addr_t dp,
				 index_space_t ** isp_ret, dp_addr_t * phys_dp);
void isp_set_buffer (index_space_t * space_to, dp_addr_t logical_dp,
		     dp_addr_t physical_dp, buffer_desc_t * buf);
buffer_desc_t * itc_delta_this_buffer (it_cursor_t * itc, buffer_desc_t * buf, int stay_in_map);
#define DELTA_STAY_INSIDE 1
#define DELTA_MAY_LEAVE 0





dbe_schema_t * isp_schema (void * thr);

buffer_desc_t * isp_new_page (index_space_t * isp, dp_addr_t nearxx, int type, int in_pmap, int has_hold);
void isp_free_page (index_space_t * isp, buffer_desc_t * buf);
void isp_free_blob_dp_no_read (index_space_t * isp, dp_addr_t dp);

void isp_delete_delta_pages (index_space_t * isp);
void isp_merge (index_space_t * isp_from, index_space_t * isp_into);
index_space_t * itc_register_space (it_cursor_t * it, buffer_desc_t *);
void it_make_checkpoint (index_tree_t * it, char * log_name);

void isp_close_snapshot (index_space_t * isp);
void isp_open_snapshot (index_space_t * isp);
void isp_kill_snapshots (void);

void it_cache_check (index_tree_t * it);

void it_cache_check (index_tree_t * it);


/* lock.c */


extern resource_t * idp_rc;


/* row.c */

dbe_col_loc_t * key_find_cl (dbe_key_t * key, oid_t col);
dbe_col_loc_t *cl_list_find (dbe_col_loc_t * cl, oid_t col_id);
search_spec_t * key_add_spec (search_spec_t * last, it_cursor_t * it,
			      dk_session_t * ses);

db_buf_t  itc_column (it_cursor_t * it, db_buf_t page, oid_t col_id);
caddr_t itc_box_row (it_cursor_t * it, db_buf_t page);

caddr_t itc_box_column (it_cursor_t * it, db_buf_t page, oid_t col, dbe_col_loc_t * cl);
long itc_long_column (it_cursor_t * it, buffer_desc_t * buf, oid_t col);
void key_free_trail_specs (search_spec_t * sp);
void itc_free_specs (it_cursor_t * it);
dbe_key_t * itc_get_row_key (it_cursor_t * it, buffer_desc_t * buf);

int itc_row_insert (it_cursor_t * it, db_buf_t row, buffer_desc_t ** unq_buf);
int itc_row_insert_1 (it_cursor_t * it, db_buf_t row, buffer_desc_t ** unq_buf,
		    int blobs_in_place, int pk_only);

void itc_drop_index (it_cursor_t * it, dbe_key_t * key);

void itc_row_key_insert (it_cursor_t * it, db_buf_t row, dbe_key_t * ins_key);



/* meta.c */
void dbe_key_free (dbe_key_t * key);
void dbe_key_layout (dbe_key_t * key);

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
struct query_s * sch_proc_exact_def (dbe_schema_t * sch, caddr_t name);
struct query_s * sch_module_def (dbe_schema_t * sch, caddr_t name);
#ifdef UNIVERSE
extern void sch_set_remote_proc_def (caddr_t name, caddr_t proc);
#endif
#define IS_REMOTE_ROUTINE_QR(qr) ((qr) && (qr)->qr_is_remote_proc)
void sch_set_proc_def (dbe_schema_t * sch, caddr_t name,  struct query_s * qr);
void sch_set_module_def (dbe_schema_t * sch, caddr_t name,  struct query_s * qr);
caddr_t numeric_from_x (numeric_t res, caddr_t x, int prec, int scale, char * col_name, oid_t cl_id, dbe_key_t *key);
void sch_drop_module_def (dbe_schema_t *sc, struct query_s *mod_qr);

void row_print_object (caddr_t thing, dk_session_t * ses, dbe_column_t * col, caddr_t * err_ret);
dk_set_t key_ensure_visible_parts (dbe_key_t * key);
void row_print_blob (it_cursor_t * itc, caddr_t thing, dk_session_t * ses, dbe_column_t * col,
    caddr_t * err_ret);

int upd_blob_opt (it_cursor_t * itc, db_buf_t row,
	      caddr_t * err_ret,
	      int log_as_insert);

extern int case_mode;
#define CM_UPPER 1
#define CM_SENSITIVE 0
#define CM_MSSQL 2

#define CASEMODESTRCMP(s1, s2) (case_mode == CM_MSSQL ? stricmp((s1), (s2)) : strcmp((s1), (s2)))
#define CASEMODESTRNCMP(s1, s2, n) (case_mode == CM_MSSQL ? strnicmp((s1), (s2), (n)) : strncmp((s1), (s2), (n)))
/* outline versions for external apps */
int casemode_strcmp (const char *s1, const char *s2);
int casemode_strncmp (const char *s1, const char *s2, size_t n);

caddr_t sqlp_box_id_upcase (const char *str);
void sqlp_upcase (char *str);
caddr_t sqlp_box_upcase (const char *str);

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
#if UNIVERSE
extern unsigned long vdb_oracle_catalog_fix; /* from odbccat.c */
extern long vdb_attach_autocommit; /* from odbccat.c */
extern long rds_disconnect_timeout; /* from sqlrrun.c */
extern int32 vdb_client_fixed_thread;
extern int prpc_disable_burst_mode;
extern int prpc_forced_fixed_thread;
extern int prpc_force_burst_mode;
extern long prpc_burst_timeout_msecs;
#endif
extern int sqlo_max_layouts;
extern long txn_after_image_limit;
extern long stripe_growth_ratio;
extern int disable_listen_on_unix_sock;
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



/* ddlrun.c */

caddr_t isp_read_object_schema (index_space_t * isp, lock_trx_t * lt,
			     dbe_schema_t * sp);
void ddl_ensure_stat_tables (void);

void sqlc_quote_dotted_quote (char *text, size_t tlen, int *fill, char *name, const char *quote);


/* log.c */

void log_replay_file (int fd);
void log_checkpoint (dbe_storage_t * dbs, char * new_file, int shutdown);
void log_delete (lock_trx_t * lt, it_cursor_t * it, db_buf_t page, int pos);

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
blob_layout_t * bl_from_dv (dtp_t * col, it_cursor_t * itc);
blob_handle_t * bh_from_dv (dtp_t * col, it_cursor_t * itc);
void bh_to_dv (blob_handle_t * bh, dtp_t * col, dtp_t dtp);
int  blob_check (blob_handle_t * bh);
int  bl_check (blob_layout_t * bl);
#define BLOB_OK 0
#define BLOB_FREE 1

void blob_layout_free (blob_layout_t * bl);

box_t blob_layout_ctor (dtp_t blob_handle_dtp, dp_addr_t start, dp_addr_t dir_start, size_t length, size_t diskbytes, index_tree_t * it);
int blob_read_dir (it_cursor_t * itc, dp_addr_t ** pages, int * is_complete, dp_addr_t dir_start);
box_t blob_layout_from_handle_ctor (blob_handle_t *bh);
int itc_print_blob_col_non_txn (it_cursor_t * row_itc, dk_session_t * row, caddr_t data, int is_extension);
int bh_fill_buffer_from_blob (index_space_t * isp, lock_trx_t * lt, blob_handle_t * bh,
    caddr_t outbuf, long get_bytes);
void blob_chain_delete (it_cursor_t * it, blob_layout_t *bl);
void blob_send_bytes (lock_trx_t * lt, caddr_t bh, long n_bytes, int send_position);
void lt_write_blob_log (lock_trx_t * lt, dk_session_t * log_ses);
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
void blob_log_replace (it_cursor_t * it, blob_layout_t * bl);

void row_fixup_blob_refs (it_cursor_t * itc, db_buf_t row);
caddr_t blob_to_string_isp (lock_trx_t * lt, index_space_t *isp, caddr_t bhp);
caddr_t blob_to_string (lock_trx_t * lt, caddr_t bhp);
caddr_t safe_blob_to_string (lock_trx_t * lt, caddr_t bhp, caddr_t *err);
dk_session_t *blob_to_string_output_isp (lock_trx_t * lt, index_space_t *isp, caddr_t bhp);
dk_session_t *blob_to_string_output (lock_trx_t * lt, caddr_t bhp);
#if 0
caddr_t bloblike_pages_to_string (dbe_storage_t * dbs, lock_trx_t * lt, dp_addr_t start);
#endif
dk_session_t *bloblike_pages_to_string_output (dbe_storage_t * dbs, lock_trx_t * lt, dp_addr_t start);
caddr_t blob_subseq (lock_trx_t * lt, caddr_t bhp, size_t from, size_t to );
long bh_write_out (lock_trx_t * lt, blob_handle_t * bh, dk_session_t *ses);
void blob_log_write (it_cursor_t * it, dp_addr_t start, dtp_t blob_handle_dtp, dp_addr_t dir_start, long diskbytes,
		     oid_t col_id, char * tb_name);
void blob_log_set_free (s_node_t *set);
int blob_log_set_delete (dk_set_t * set, dp_addr_t dp);
int bh_fetch_dir (index_space_t * isp, lock_trx_t * lt, blob_handle_t * bh);

#define BLOB_CHANGED 1
#define BLOB_NO_CHANGE 0


/*int wide_blob_buffered_read (dk_session_t * ses_from, char* to, int req_chars, blob_state_t * state, int * page_end); now static in blob.c*/

/* Low-level read or write of a blob page, e.g., for random access */
extern int page_wait_blob_access (it_cursor_t * itc, dp_addr_t dp_to, buffer_desc_t ** buf_ret, int mode, blob_handle_t *bh, int itc_map_wrap);


/* neodisk.c */

void dbs_checkpoint (dbe_storage_t * dbs, char * log_name, int shutdown);
#define CPT_NORMAL 0
#define CPT_SHUTDOWN 1
#define CPT_INC_RESET 2
#define CPT_DB_TO_LOG 3
void dbs_read_checkpoint_remap (dbe_storage_t * dbs, dp_addr_t from);
int isp_can_reuse_logical (index_space_t * isp, dp_addr_t dp);

void isp_free_remap (index_space_t * isp, dp_addr_t logical, dp_addr_t remap);

#define DP_CHECKPOINT_REMAP(dbs, dp)\
  (gethash (DP_ADDR2VOID (dp), dbs->dbs_cpt_remap))
#define ISP_DP_TO_BUF(isp, dp) ((buffer_desc_t *) gethash (DP_ADDR2VOID (dp), isp -> isp_dp_to_buf))
int cpt_count_mapped_back (dbe_storage_t * dbs);
dp_addr_t remap_phys_key (remap_t * r);
int cpt_is_global_lock (void);


/* other */

caddr_t isp_read_object_dd (index_space_t * isp, lock_trx_t * lt,
			     dbe_schema_t * sc);


/* acc.c */




/* registry, sequences */

#define SEQUENCE_GET 2
#define SET_IF_GREATER 1
#define SET_ALWAYS 0


void registry_exec (void);
long sequence_set (char * name, long value, int mode, int in_map);
long sequence_next (char * name, int in_map);
long sequence_next_inc (char *name, int in_map, long inc_by);
long sequence_remove (char *name, int in_map);
box_t sequence_get_all ( void ); /* returns the name,value, name,value array */

EXE_EXPORT(caddr_t, registry_get, (char *name));
void registry_set_1 (char * name, char * value, int is_boxed);
#define registry_set(name,value) registry_set_1(name,value,0)
EXE_EXPORT(box_t, registry_get_all, ( void )); /* returns the name,value, name,value array */
caddr_t registry_remove (char *name);

void dbs_write_registry (dbe_storage_t * dbs);
void dbs_init_registry (dbe_storage_t * dbs);
void db_replay_registry_sequences (void);

void db_log_registry (dk_session_t * log);
caddr_t box_deserialize_string (caddr_t text, int opt_len);


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
void itc_up_transit (it_cursor_t * itc, buffer_desc_t ** buf_ret);
void isp_unregister_all (index_space_t * isp);

/* disk.c */
OFF_T dbs_extend_file (dbe_storage_t * dbs);
OFF_T dbs_extend_stripes (dbe_storage_t * dbs);


/* auxfiles.c */
dbe_storage_t *dbs_from_file (char * name, char * file, char type, volatile int * exists);
void _dbs_read_cfg (dbe_storage_t * dbs, char *file);
extern void (*dbs_read_cfg) (caddr_t * dbs, char *file);
dk_set_t _cfg_read_storages (caddr_t **temp_storage);
extern dk_set_t (*dbs_read_storages) (caddr_t **temp_file);


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
void sched_set_thread_count (void);

caddr_t box_cast_to (caddr_t *qst, caddr_t data, dtp_t data_dtp,
    dtp_t to_dtp, ptrlong prec, ptrlong scale, caddr_t *err_ret);

caddr_t box_sprintf_escaped (caddr_t str, int is_id);

void dp_set_backup_flag (dbe_storage_t * dbs, dp_addr_t page, int on);
int dp_backup_flag (dbe_storage_t * dbs, dp_addr_t page);

void hosting_plugin_init (void);
void plugin_loader_init(void);

/* bif_file.c */
void init_file_acl_set (char *acl_string1, dk_set_t * acl_set_ptr);
char *virt_strerror (int eno);



#define BYTE_ORDER_REV_SUPPORT

extern int dbs_reverse_db; /* global flag, indicates reverse order of database */
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
extern int prefix_in_result_col_names;
extern int is_crash_dump;

extern void (*db_exit_hook) (void);
extern long last_flush_time;
extern long last_exec_time;	/* used to know when the system is idle */

extern unsigned long int cfg_autocheckpoint;	/* Defined in disk.c */
extern int32 c_checkpoint_interval;
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

#endif /* _WIFN_H */
