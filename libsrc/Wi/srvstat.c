/*
 *  srvstat.c
 *
 *  $Id$
 *
 *  Server Status Report
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

#include "Dk.h"
#include "Dk/Dksestcp.h"
#include "sqlnode.h"
#include "sqlfn.h"
#include "repl.h"
#include "sqlbif.h"
#include "sqlver.h"
#include "recovery.h"
#include "security.h"
#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include "srvmultibyte.h"
#include "sqltype.h"
#ifdef BIF_XML
#include "xmltree.h"
#endif
#include "http.h"
#include "srvstat.h"
#include "bif_text.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "datesupp.h"

#ifndef WIN32
# include <pwd.h>
# include <unistd.h>
#endif

#ifdef __APPLE__
#include <sys/types.h>
#include <sys/sysctl.h>
#endif



long  tc_try_land_write;
long  tc_try_land_reset;
long tc_up_transit_parent_change;
long tc_dp_set_parent_being_read;
long tc_dp_changed_while_waiting_mtx;
long  tc_dive_split;
long  tc_dtrans_split;
long  tc_up_transit_wait;
long  tc_double_deletes;
long  tc_delete_parent_waits;
long  tc_wait_trx_self_kill;
long  tc_split_while_committing;
long  tc_rb_code_non_unique;
long  tc_set_by_pl_wait;
long  tc_split_2nd_read;
long  tc_read_wait;
long  tc_write_wait;
long tc_qp_thread;
long tc_dive_would_deadlock;
long tc_cl_deadlocks;
long tc_cl_wait_queries;
long tc_cl_kill_1pc;
long tc_cl_kill_2pc;
long tc_atomic_wait_2pc;
long tc_cl_alt_interface;
long tc_anytime_early_flush;
long tc_cl_keep_alives;
long tc_cl_branch_wanted_queries;
long tc_cl_consensus_rollback;
long tc_cl_consensus_commit;
long tc_cl_consensus_deferred;
long tc_cl_branch_missed_rb;
long tc_cl_keep_alive_timeouts;
long tc_cl_commit_resend;
long tc_cl_disconnect;
long tc_cl_disconnect_in_clt;
long tc_dfg_coord_pause;
long tc_dfg_more;
int cls_rollback_no_finish_if_thread;


long tc_page_fill_hash_overflow;
extern long tc_part_hash_join;
long tc_key_sample_reset;
long tc_pl_moved_in_reentry;
long tc_enter_transiting_bm_inx;
long tc_geo_delete_retry, tc_geo_delete_missed;
extern long tc_aio_seq_read;
extern long tc_aio_seq_write;

long tc_read_absent_while_finalize;
extern long tc_merge_reads;
extern long tc_merge_read_pages;

long tc_fix_outdated_leaf_ptr;
long tc_bm_split_left_separate_but_no_split;
long tc_aq_sleep;
long tc_root_write;
long tc_root_image_miss;
long tc_root_image_ref_deleted;
long tc_uncommit_cpt_page;

long tc_unregister_enter;
long tc_root_cache_miss;
long  tc_reentry_split;
long  tc_release_pl_on_deleted_dp;
long  tc_release_pl_on_absent_dp;
long  tc_cpt_lt_start_wait;
long  tc_cpt_rollback;
long  tc_wait_for_closing_lt;
long  tc_pl_non_owner_wait_ref_deld;
long  tc_pl_split;
long  tc_pl_split_multi_owner_page;
long  tc_pl_split_while_wait;
long  tc_insert_follow_wait;
long  tc_history_itc_delta_wait;
long  tc_page_wait_reset;
long  tc_posthumous_lock;
long  tc_finalize_while_being_read;
long  tc_rollback_cpt_page;
long  tc_kill_closing;
long  tc_dive_cache_hits;
long  tc_deadlock_win_get_lock;
long  tc_double_deadlock;
long  tc_update_wait_move;
long  tc_cpt_rollback_retry;
long  tc_repl_cycle;
long  tc_repl_connect_quick_reuse;

long  tc_no_thread_kill_idle;
long  tc_no_thread_kill_vdb;
long  tc_no_thread_kill_running;
long  tc_deld_row_rl_rb;

long  tc_blob_read;
long  tc_blob_write;
long  tc_blob_ra;
long  tc_blob_ra_size;
long  tc_get_buf_failed;
long  tc_read_wait_decoy;
long  tc_read_wait_while_ra_finding_buf;
long  tc_pg_write_compact;
long dbf_user_1, dbf_user_2;


extern long read_block_usec;
extern long write_block_usec;
extern long tc_initial_while_closing;
extern long tc_initial_while_closing_died ;
extern long tc_client_dropped_connection ;
extern long tc_no_client_in_tp_data ;
extern long tc_bp_get_buffer;
extern long tc_bp_get_buffer_loop ;
extern long tc_first_free_replace ;
extern long tc_hi_lock_new_lock ;
extern long tc_hi_lock_old_dp_no_lock ;
extern long tc_hi_lock_old_dp_no_lock_deadlock;
extern long tc_hi_lock_old_dp_no_lock_put_lock;
extern long tc_hi_lock_lock;
extern long tc_hi_lock_lock_deadlock;
extern long tc_write_cancel;
extern long tc_write_scrapped_buf;
extern long tc_serializable_land_reset;
extern long tc_dive_cache_compares;
extern long tc_desc_serial_reset;
extern long tc_dp_set_parent_being_read;
extern long tc_reentry_split;
extern long tc_kill_closing;
extern long tc_get_buf_failed;
extern long tc_unused_read_aside;
extern long tc_read_aside;
extern long tc_adjust_batch_sz;
extern long tc_cum_batch_sz;
extern long tc_no_mem_for_longer_batch;
extern long tc_dc_max_alloc;
extern long tc_dc_default_alloc;
extern long tc_dc_alloc;
extern long tc_dc_size;
extern long tc_dc_extend;
extern long tc_dc_extend_values;


extern int32 em_ra_window;
extern int32 em_ra_threshold;
extern int enable_mem_hash_join;
#ifdef CACHE_MALLOC
extern int enable_no_free;
#endif
extern int32 enable_rdf_box_const;
extern int enable_subscore;
extern int enable_dfg;
extern int enable_feed_other_dfg;
extern long tc_cll_undelivered;
extern long tc_over_max_undelivered;
extern int enable_rec_qf;
extern int enable_cm_trace;
extern int enable_listener_prio;
extern int enable_cll_nb_read;
extern int enable_high_card_part;
extern int enable_nb_clrg;
extern long tc_compress_clocks;
extern long tc_uncompress_clocks;
extern int enable_cl_compress;
extern int enable_conn_rc_fifo;
extern int enable_cm_still_wanted;
extern int enable_cancel_waiting;
extern int enable_setp_partition;
extern int enable_stream_gb;
extern int enable_min_card;
extern int enable_hash_colocate;
extern int enable_dfg_print;
extern int dbf_cl_cancel_trap;
extern int enable_itc_dfg_ck;
int enable_daq_trace = 0;
extern int dfg_max_empty_mores;
extern int dfg_empty_more_pause_msec;
extern long tc_dfg_max_empty_mores;
extern int mp_local_rc_sz;
extern int enable_distinct_sas;
int32 ha_rehash_pct = 300;
extern int c_use_aio;
extern int32 sqlo_sample_dep_cols;
extern int32 allow_part_read;
int c_no_dbg_print;
extern long strses_file_reads;
extern long strses_file_seeks;
extern long strses_file_writes;
extern long strses_file_wait_msec;

long  tft_random_seek;
long  tft_seq_seek;

extern int dbf_explain_level;
long  prof_on;
long  prof_stat_table;
long prof_start_time;
time_t prof_start_time_st;
unsigned long  prof_n_exec;
unsigned long  prof_n_reused;
unsigned long  prof_exec_time;
unsigned long prof_avg_exec;
unsigned long  prof_n_compile;
unsigned long  prof_compile_time;

unsigned long vdb_n_exec;
unsigned long vdb_n_fetch;
unsigned long vdb_n_transact;
unsigned long vdb_n_error;

long ac_pages_in;
long ac_pages_out;
long ac_col_pages_in;
long ac_col_pages_out;
extern uint32 ac_cpu_time;
extern uint32 ac_real_time;
extern int ac_n_times;
extern uint32 col_ac_last_duration;
long ac_n_busy;


long tws_connections;
long tws_requests;
long tws_1_1_requests;
long tws_slow_keep_alives;
long tws_immediate_reuse;
long tws_slow_reuse;
long tws_accept_queued;
long tws_accept_requeued;
long tws_keep_alive_ready_queued;
long tws_early_timeout;
long tws_disconnect_while_check_in;
long tws_done_while_check_in;
long tws_cancel;
long tws_bad_request;

long tws_cached_connection_hits;
long tws_cached_connection_miss;
long tws_cached_connections_in_use;
long tws_cached_connections;

long vt_batch_size_limit = 1000000L;

/* flags for simulated exceptions */
long dbf_no_disk = 0;
long dbf_log_no_disk;
long dbf_2pc_prepare_wait; /* wait this many msec between prepare and commit */
long dbf_2pc_wait; /* wait this many msec after each 2pc message or log write */
long dbf_branch_transact_wait; /* wait this many msec onn cluster branch before doing rollback, prepare or commit */
long dbf_clop_enter_wait;
long dbf_cl_skip_wait_notify;
long dbf_cpt_rb;
long dbf_cl_blob_autosend_limit = 2000000;
long dbf_no_sample_timeout = 0;
extern int dbf_compress_mask;
extern int dbf_ce_insert_mask;
extern int dbf_ce_del_mask;
extern int dbf_col_ins_dbg_log;
extern int dbf_col_del_leaf;
extern int enable_pogs_check;
int key_seg_check[10];
int dbf_fast_cpt = 0;
extern int enable_hash_join;
extern int enable_hash_merge;
extern int enable_hash_fill_join;
extern int enable_vec;
extern int32 enable_qp;
extern int32 enable_qn_cache;
extern int32 enable_mt_txn;
extern int32 enable_mt_transact;
extern int32 enable_lead_subq_colocate;
extern int64 mp_mmap_clocks;
extern int64 ql_ctr;
extern int aq_max_threads;
extern int qp_even_if_lock;
extern int qp_thread_min_usec;
extern int qp_range_split_min_rows;
extern int enable_ac;
extern int enable_col_ac;
extern int col_ins_error;
extern int enable_ce_ins_check;
int dbf_ignore_uneven_col;
extern int enable_buf_mprotect;
extern int enable_ro_rc;
extern int32 dc_batch_sz;
extern int32 dc_max_batch_sz;
extern int32 enable_dyn_batch_sz;
extern int32 dc_adjust_batch_sz_min_anytime;
extern int32 enable_vec_reuse;
extern int enable_split_range;
extern int enable_split_sets;

extern int32 c_cluster_threads;
extern int32 cl_msg_drop_rate;
extern int32 cl_con_drop_rate;
extern int32 cl_keep_alive_interval;
extern int32 cl_max_keep_alives_missed;
extern int32 cl_non_logged_write_mode;
extern int32 cl_dead_w_interval;
extern int32 cl_mt_read_min_bytes;
extern int32 cl_stage;
extern int32 cl_batch_bytes;
extern int32 cl_first_buf;
extern int32 iri_range_size;
int64 tn_max_memory = 1000000000;
extern int64 tn_at_mem_cutoff;
extern int64 tn_mem_cutoff;
extern int64 tn_at_card_cutoff;
extern int64 tn_card_cutoff;
extern size_t cha_max_gb_bytes;

extern int64 chash_space_avail;
extern int chash_per_query_pct;
extern int enable_chash_gb;
extern long tc_slow_temp_insert;
extern long tc_slow_temp_lookup;
extern int enable_ksp_fast;
int cl_log_from_sync = 0;
int cl_no_auto_remove;
extern int dbf_log_fsync;
extern int dbf_assert_on_malformed_data;
extern int dbf_max_itc_samples;

void trset_start (caddr_t * qst);
void trset_printf (const char *str, ...);
void trset_end ();

#define rep_printf	trset_printf

/* status to sys_stat variables */
char st_dbms_name_buffer[1000];
char *st_dbms_name = st_dbms_name_buffer;
char *st_dbms_ver = DBMS_SRV_VER;
long st_proc_served;
long st_proc_active;
long st_proc_running;
long st_proc_queued_req;
unsigned ptrlong st_proc_brk;

char st_db_file_size_buffer[50];
char *st_db_file_size = st_db_file_size_buffer;
long st_db_pages;
long st_db_page_size = PAGE_SZ;
long st_db_page_data_size = PAGE_DATA_SZ;
long st_db_free_pages;
long st_db_buffers;
long st_db_used_buffers;
long st_db_dirty_buffers;
long st_db_wired_buffers;
long st_db_temp_pages;
long st_db_temp_free_pages;

long st_db_disk_read_avg;
long st_db_disk_read_pct;
long st_db_disk_read_last;
long st_db_disk_read_aheads;
long st_db_disk_read_ahead_batch;
long st_db_disk_second_reads;
long st_db_disk_in_while_read;
char *st_db_disk_mt_write;
char *st_db_log_name;
char st_db_log_length_buffer[50];
char *st_db_log_length = st_db_log_length_buffer;
char *st_rpc_stat;
time_t st_started_since;
long st_started_since_year;
long st_started_since_month;
long st_started_since_day;
long st_started_since_hour;
long st_started_since_minute;
long st_sys_ram;

long st_chkp_remap_pages;
long st_chkp_mapback_pages;
long st_chkp_atomic_time;

long st_cli_n_current_connections = 0;

long fe_replication_support = 0;

long sparql_result_set_max_rows = 0;
long sparql_max_mem_in_use = 0;

extern int rdf_create_graph_keywords;
extern int rdf_query_graph_keywords;

static long thr_cli_running;
static long thr_cli_waiting;
static long thr_cli_vdb;

static long db_max_col_bytes = ROW_MAX_COL_BYTES;
static long db_sizeof_wide_char = sizeof (wchar_t);

void
process_status_report (void)
{
#if defined (UNIX) && !defined PMN_THREADS
  USE_GLOBAL
  int n;
  int active = 0, running = 0, served = 0;

  active = 0;
  running = 0;
  served = 0;

  for (n = 0; n < MAX_THREADS; n++)
    {
      if (threads[n].thr_IsActive)
	{
	  active++;
	  if (threads[n].thr_status == RUNNABLE)
	    running++;
	}
    }
  for (n = 0; n < MAX_SESSIONS; n++)
    {
      if (served_sessions[n])
	served++;
    }
  rep_printf ("Server status: %d served sessions, %d threads, %d running.\n",
      served, active, running);
  st_proc_served = served;
  st_proc_running = running;
  st_proc_active = active;
  {
    s_node_t *token = in_basket.first_token;
    n = 0;
    while (token)
      {
	n++;
	token = token->next;
      }
    st_proc_brk  = (unsigned ptrlong) sbrk (0) - initbrk;
    rep_printf ("	    %d requests queued.  brk = %Ld\n", n,
	(unsigned int64) st_proc_brk);
    st_proc_queued_req = n;
  }
#endif
}



int
dbs_mapped_back (dbe_storage_t * dbs)
{
  int n_back = 0, n_new = 0, inx;
  if (dbs->dbs_type != DBS_PRIMARY && DBS_ELASTIC != dbs->dbs_type)
    return 0;
  if (dbs->dbs_slices)
    return 0;
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      for (inx = 0; inx < IT_N_MAPS; inx++)
	{
      ptrlong dp, phys_dp;
      dk_hash_iterator_t hit;
	  mutex_enter (&it->it_maps[inx].itm_mtx);
	  dk_hash_iterator (&hit, &it->it_maps[inx].itm_remap);
      while (dk_hit_next (&hit, (void**) &dp, (void**) &phys_dp))
	{
	  if (dp == phys_dp)
	    {
	      if (gethash (DP_ADDR2VOID (dp), dbs->dbs_cpt_remap))
		n_back++;
	      else
		n_new++;
	    }
	    }
	  mutex_leave (&it->it_maps[inx].itm_mtx);
	}

    }
  END_DO_SET ();
  return n_back;
}


void
wi_storage_report ()
{
  DO_SET (wi_db_t *, wd, &wi_inst.wi_dbs)
    {
      DO_SET (dbe_storage_t *, dbs, &wd->wd_storage)
	{
	  if (DBS_ELASTIC == dbs->dbs_type && dbs->dbs_slices)
	    continue;
	  rep_printf ("    %s %s %d total %d free %d remap %d mapped back\n",
		      wd->wd_qualifier, dbs->dbs_name,
		      dbs->dbs_n_pages, dbs_count_free_pages (dbs),
		      dbs->dbs_cpt_remap->ht_count, dbs_mapped_back (dbs));
	}
      END_DO_SET();
    }
  END_DO_SET();
  st_db_temp_pages = wi_inst.wi_temp->dbs_n_pages;
  st_db_temp_free_pages = dbs_count_free_pages (wi_inst.wi_temp);
  rep_printf ("   temp  %ld total %ld free\n", st_db_temp_pages, st_db_temp_free_pages);
}


void
list_wired_buffers (char *file, int line, char *format, ...)
{
  /*dbe_storage_t * dbs = wi_inst.wi_master;*/
  int wired_ctr = 0;
  int binx, inx;
  if (1)
    {
      DO_BOX (buffer_pool_t *, bp, binx, wi_inst.wi_bps)
	{
	  buffer_desc_t * buf;
	  mutex_enter (bp->bp_mtx);
	  for (inx = 0; inx < bp->bp_n_bufs; inx++)
	    {
	      buf = &bp->bp_bufs[inx];
	      if (BUF_WIRED (buf))
		{
		  va_list va;
		  printf ("\nWired buffer (%s:%d) ", file, line);
		  va_start (va, format);
		  vprintf (format, va);
		  va_end (va);
		  log_error ("Wired buffer detected (%s:%d) ", file, line);
		  wired_ctr++;
		}
	    }
	  mutex_leave (bp->bp_mtx);
	}
      END_DO_BOX;
    }
  if (wired_ctr)
    log_error ("%d wired buffers detected (%s:%d) ", wired_ctr, file, line);
}

void
dbms_status_report (void)
{
  dbe_storage_t * dbs = wi_inst.wi_master;
  int binx, inx;
  char mem[100];
  char rpc[200];
  char col_ac_str[100];
  long read_percent = 0, write_percent = 0, interval_msec = 0;
  static long last_time;
  static long last_read_cum_time, last_write_cum_time;
  int n_dirty = 0, n_wired = 0, n_buffers = 0, n_used = 0, n_io = 0, n_crsr = 0;
  char * bp_curr_ts;
  dk_mem_stat (mem, sizeof (mem));
  PrpcStatus (rpc, sizeof (rpc));
  if (1)
    {
      if (last_time)
	{
	  interval_msec = get_msec_real_time () - last_time;
	  if (!interval_msec)
	    interval_msec = 1;
	  read_percent = ((read_cum_time - last_read_cum_time) * 100) / interval_msec;
	  write_percent = ((write_cum_time - last_write_cum_time) * 100) / interval_msec;
	}
      last_read_cum_time = read_cum_time;
      last_write_cum_time = write_cum_time;
      last_time = get_msec_real_time ();
      DO_BOX (buffer_pool_t *, bp, binx, wi_inst.wi_bps)
	{
	  buffer_desc_t * buf;
	  mutex_enter (bp->bp_mtx);
	  for (inx = 0; inx < bp->bp_n_bufs; inx++)
	    {
	      buf = &bp->bp_bufs[inx];
	      n_buffers++;
	      if (buf->bd_tree)
		n_used++;
	      if (buf->bd_registered)
		n_crsr++;
	      if (BUF_WIRED (buf))
		n_wired++;
	      if (buf->bd_is_dirty)
		n_dirty++;
	      if (buf->bd_iq)
		n_io++;
	    }
	  mutex_leave (bp->bp_mtx);
	}
      END_DO_BOX;

      st_db_free_pages = dbs_count_free_pages (dbs);
      rep_printf ("\nDatabase Status:\n"
	  "  File size " OFF_T_PRINTF_FMT ", %ld pages, %ld free.\n"
	  "  %d buffers, %d used, %d dirty %d wired down, repl age %d %d w. io %d w/crsr.\n",
	  (OFF_T_PRINTF_DTP) dbs->dbs_file_length, dbs->dbs_n_pages,
	  st_db_free_pages,
	  n_buffers, n_used, n_dirty, n_wired,
		  bp_replace_count ? (int) (bp_replace_age / bp_replace_count) : 0, n_io, n_crsr );
      snprintf (st_db_file_size, sizeof (st_db_file_size_buffer), OFF_T_PRINTF_FMT,
	  (OFF_T_PRINTF_DTP) (dbs->dbs_n_pages * PAGE_SZ));
      st_db_pages = dbs->dbs_n_pages;
      st_db_buffers = n_buffers;
      st_db_used_buffers = n_used;
      st_db_dirty_buffers = n_dirty;
      st_db_wired_buffers = n_wired;
      if (ac_col_pages_in)
	snprintf (col_ac_str, sizeof (col_ac_str), " col ac: %ld in %ld%% saved", ac_col_pages_in, 100 * (ac_col_pages_in - ac_col_pages_out) / (1 + ac_col_pages_in));
      else
	col_ac_str[0] = 0;
      rep_printf ("  Disk Usage: %ld reads avg %ld msec, %d%% r %d%% w last  %ld s, %ld writes,\n    %ld read ahead, batch = %ld.  Autocompact %ld in %ld out, %ld%% saved%s.\n",
	  disk_reads, read_cum_time / (disk_reads ? disk_reads : 1),
		  read_percent, write_percent, interval_msec / 1000, disk_writes, ra_count, ra_pages / (ra_count + 1), ac_pages_in, ac_pages_out, 100 * (ac_pages_in - ac_pages_out) / (1 + ac_pages_in), col_ac_str);

      st_db_disk_read_avg = read_cum_time / (disk_reads ? disk_reads : 1);
      st_db_disk_read_pct = read_percent;
      st_db_disk_read_last = interval_msec / 1000;
      st_db_disk_read_aheads = ra_count;
      st_db_disk_read_ahead_batch = ra_pages / (ra_count + 1);
    }
  rep_printf ("Gate:  %ld 2nd in reads, %ld gate write waits, %ld in while read %ld busy scrap. %s\n",
      second_reads, 0, in_while_read, busy_pre_image_scrap,
      disk_no_mt_write ? "no mt write" : "");
  st_db_disk_second_reads = second_reads;
  st_db_disk_in_while_read = in_while_read;
  st_db_disk_mt_write = (char *) (disk_no_mt_write ? "no" : "yes");
  rep_printf ("Log = %s, " OFF_T_PRINTF_FMT " bytes\n",
	      dbs->dbs_log_name ? dbs->dbs_log_name : "none",
	      (OFF_T_PRINTF_DTP) dbs->dbs_log_length);
  rep_printf ("%ld pages have been changed since last backup (in checkpoint state)\n", dbs_count_incbackup_pages (dbs));

  bp_curr_ts = bp_curr_timestamp ();
  rep_printf ("Current backup timestamp: %s\n", bp_curr_ts);
  dk_free_box (bp_curr_ts);

  bp_curr_ts = bp_curr_date ();
  rep_printf ("Last backup date: %s\n", bp_curr_ts);
  dk_free_box (bp_curr_ts);

  st_db_log_name = (char *) (dbs->dbs_log_name ? dbs->dbs_log_name : "none");
  snprintf (st_db_log_length, sizeof (st_db_log_length_buffer), OFF_T_PRINTF_FMT,
      (OFF_T_PRINTF_DTP)dbs->dbs_log_length);
  rep_printf ("Clients: %ld connects, max %ld concurrent\n",
      srv_connect_ctr, srv_max_clients);
  rep_printf ("%s %s\n", rpc, mem);
  dk_free_box (st_rpc_stat);
  st_rpc_stat = box_dv_short_string (rpc);
}


long isp_r_new;
long isp_r_delta;


void
isp_rep_map_fn (void *key, void *value)
{
#ifndef O12
  dp_addr_t from = (dp_addr_t) key;
  dp_addr_t to = (dp_addr_t) value;

  if (from == to)
    isp_r_new++;
  else
    isp_r_delta++;
#endif
}


#define PRINT_MAX_LOCKS 1000


void
trx_status_report (lock_trx_t * lt)
{
  int nth = 0;
  IN_TXN;
    {
      rep_printf ("Transaction status: %s, %d threads.\n",
	  lt->lt_status == LT_PENDING ? "PENDING" :
	  (lt->lt_status == LT_BLOWN_OFF_C ? "BLOWN OFF" : "ROLLED BACK"),
	  lt->lt_threads);

      if (lt->lt_status == LT_PENDING)
	{
	  rep_printf ("Locks: ");
	  IN_LT_LOCKS (lt);
	  DO_HT (page_lock_t *, pl, void *, ign, &lt->lt_lock)
	  {
	    it_cursor_t *waiting = pl->pl_waiting;
	    int wait = 0;
	    if (nth++ > 10)
	      {
		rep_printf ("....");
		break;
	      }
	    while (waiting)
	      {
		if (waiting->itc_ltrx == lt)
		  {
		    wait = 1;
		    rep_printf ("   %ld: W%s, ", pl->pl_page,
			waiting->itc_lock_mode == PL_SHARED ? "S" : "E");
		    break;
		  }
		waiting = waiting->itc_next_on_lock;
	      }
	    if (!wait)
	      {
		rep_printf ("%ld: I%s, ", pl->pl_page,
		    pl->pl_type == PL_SHARED ? "S" : "E");
	      }
	  }
	  END_DO_HT;
	  LEAVE_LT_LOCKS (lt);
	  rep_printf ("\n");
	}
    }
    LEAVE_TXN;
}




void
cli_status_report (dk_session_t * ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);
  user_t * user;
  char from[16] = "";
  if (!cli)
    return;
  user = cli->cli_user;
  rep_printf ("\nClient %s:  Account: %s, " OFF_T_PRINTF_FMT " bytes in, "
      OFF_T_PRINTF_FMT " bytes out, %ld stmts.\n",
      ses->dks_peer_name ? ses->dks_peer_name : "<NOT_CONN>",
      user && user->usr_name ? user->usr_name : "unknown", (OFF_T_PRINTF_DTP) ses->dks_bytes_received,
      (OFF_T_PRINTF_DTP) ses->dks_bytes_sent,
      cli->cli_statements->ht_inserts - cli->cli_statements->ht_deletes);
  if (ARRAYP(cli->cli_info) && BOX_ELEMENTS (cli->cli_info) > 5)
    {
      caddr_t app_name = cli->cli_info[0];
      tcpses_print_client_ip (ses->dks_session, from, sizeof (from));
      rep_printf ("PID: %ld, OS: %s, Application: %s, IP#: %s\n",
	  	(long) (cli->cli_info[1]),
		cli->cli_info[3],
		app_name[0] ? app_name : "unknown",
		from);
    }
  if (!cli->cli_trx)
    return;
  trx_status_report (cli->cli_trx);
}


#define CLI_NAME(cli) \
  (cli->cli_session && cli->cli_session->dks_peer_name ? cli->cli_session->dks_peer_name : "<NOT_CONN>")


int locks_printed;
jmp_buf_splice locks_done;


const char *
lt_short_name (lock_trx_t * lt)
{
  const char * name;
  const char * last;

  if (!lt->lt_client)
    return "NO_CLIENT";
  if (lt->lt_client->cli_ws) /* http client, print the client IP */
    return lt->lt_client->cli_ws->ws_client_ip ? lt->lt_client->cli_ws->ws_client_ip : "VSP";
  name = lt->lt_client->cli_session ?
      (lt->lt_client->cli_session->dks_peer_name ? lt->lt_client->cli_session->dks_peer_name : "NO_CONN") :
      "INTERNAL";
  last = strchr (name, ':');
  if (last)
    return (last + 1);
  return name;
}


void
gen_lock_status (gen_lock_t * pl, char * indent, long id)
{
  it_cursor_t *waiting = pl->pl_waiting;
  if (locks_printed++ > PRINT_MAX_LOCKS)
    {
      rep_printf ("More locks....\n");
      longjmp_splice (&locks_done, 1);
    }
  rep_printf ("%s%ld: I%s%s ", indent, id, PL_TYPE (pl) == PL_EXCLUSIVE ? "E" : "S",
	      PL_IS_PAGE (pl) ? "P": "R");
  if (NULL == pl->pl_owner)
    {
      rep_printf ("NO OWNER ");
    }
  else if (pl->pl_is_owner_list)
    {
      DO_SET (lock_trx_t *, lt, (dk_set_t *) & pl->pl_owner)
      {
	rep_printf (" %s", lt_short_name (lt));
      }
      END_DO_SET ();
    }
  else
    {
      rep_printf ("%s ", lt_short_name (pl->pl_owner));
    }
  if (waiting)
    rep_printf (" Waiting: ");
  while (waiting)
    {
      rep_printf ("%s ", lt_short_name (waiting->itc_ltrx));
      waiting = waiting->itc_next_on_lock;
    }
  rep_printf ("\n");
}


void
lock_status (const void *key, void *value)
{
  page_lock_t * pl = (page_lock_t*) value;
  if (pl->pl_page != (dp_addr_t) (ptrlong) key)
    rep_printf ("*** it_locks %ld, pl_page %ld\n", key, pl->pl_page);
  gen_lock_status ((gen_lock_t *) pl, "  ", pl->pl_page);
  if (! PL_IS_PAGE (pl))
    {
      DO_RLOCK (rl, pl)
	{
	  gen_lock_status ((gen_lock_t *) rl, "      ", rl->rl_pos);
	}
      END_DO_RLOCK;
    }
}


void
lt_wait_status (void)
{
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (lt->lt_waits_for || lt->lt_waiting_for_this)
	{
	  char since[40];
	  since[0] = 0;
	  if (lt->lt_waits_for)
	    snprintf (since, sizeof (since), "for %ld ms ", (long)(get_msec_real_time () - lt->lt_wait_since));
	  rep_printf ("Trx %s s=%d %p: %s w. for: ", lt_short_name (lt), lt->lt_status, lt, since);
	  DO_SET (lock_trx_t *, w, &lt->lt_waits_for)
	    {
	      rep_printf (" %s ", lt_short_name (w));
	    }
	  END_DO_SET();
	  rep_printf ("\n   is before: ");
	  DO_SET (lock_trx_t *, w, &lt->lt_waiting_for_this)
	    {
	      rep_printf (" %s ", lt_short_name (w));
	    }
	  END_DO_SET();
	  rep_printf ("\n");
	}
    }
 END_DO_SET();
}


void
cl_lt_wait_status (void)
{
}


void
bif_exec_status ()
{
  id_hash_iterator_t hit;
  int64 *k;
  bif_exec_stat_t * exs;
  uint32 now = get_msec_real_time ();
  mutex_enter (&bif_exec_pending_mtx);
  id_hash_iterator (&hit, bif_exec_pending);
  while (hit_next (&hit, (caddr_t*)&k, (caddr_t*)&exs))
    {
      rep_printf ("%d  %s\n", now - exs->exs_start, exs->exs_text);
    }

  mutex_leave (&bif_exec_pending_mtx);
}




void
cl_srv_status ()
{
}


void
srv_lock_report (const char * mode)
{
  int thr_ct = 0, lw_ct = 0, vdb_ct = 0, inx;
  IN_TXN;
  DO_SET (lock_trx_t *, lt, &all_trxs)
  {
    if (lt != bootstrap_cli->cli_trx)
      {
	thr_ct += lt->lt_threads;
	lw_ct += lt->lt_lw_threads;
	vdb_ct += lt->lt_vdb_threads;
      }
  }
  END_DO_SET ();
  thr_cli_running = thr_ct;
  thr_cli_waiting = lw_ct;
  thr_cli_vdb = vdb_ct;
  rep_printf (
      "\nLock Status: %ld deadlocks of which %ld 2r1w, %ld waits,"
      "\n   Currently %d threads running %d threads waiting %d threads in vdb."
      "\nPending:\n", lock_deadlocks, lock_2r1w_deadlocks,
      lock_waits, thr_ct, lw_ct, vdb_ct);

  if (!strchr (mode, 'l'))
    {
      LEAVE_TXN;
      return;
    }
  DO_SET (index_tree_t *, it, &wi_inst.wi_master->dbs_trees)
  {
    for (inx = 0; inx < IT_N_MAPS; inx++)
      {
	if (mutex_try_enter (it->it_lock_release_mtx))
	  {			/* prevent read release as lock release is outside of TXN mtx */
	    mutex_enter (&it->it_maps[inx].itm_mtx);
	    if (0 == setjmp_splice (&locks_done))
	      {
		locks_printed = 0;
		maphash (lock_status, &it->it_maps[inx].itm_locks);
	      }
	    mutex_leave (&it->it_maps[inx].itm_mtx);
	    mutex_leave (it->it_lock_release_mtx);
	  }
      }
  }
  END_DO_SET ();
  lt_wait_status ();
  cl_lt_wait_status ();
  LEAVE_TXN;
}


char *
stat_skip_dots (char *x)
{
  char *x1 = x + strlen (x) - 1;
  while (x1 > x)
    {
      if (*x1 == '.')
	return (x1 + 1);
      x1--;
    }
  return x;
}


int
it_remap_count (index_tree_t * it)
{
  int sum = 0,  inx;
  for (inx = 0; inx < IT_N_MAPS; inx++)
    sum += it->it_maps[inx].itm_remap.ht_count;
  return sum;
}

void
hic_status ()
{
  index_tree_t * it;
  mutex_enter (hash_index_cache.hic_mtx);
  rep_printf ("\n\nHash indexes\n");
  for (it = hash_index_cache.hic_first; it; it = it->it_hic_next)
    {
      hi_signature_t * hsi = it->it_hi_signature;
      int n_cols = box_length ((caddr_t) hsi->hsi_col_ids) / sizeof (oid_t);
      int n_keys = (int) unbox (hsi->hsi_n_keys);
      int inx;
      for (inx = 0; inx < n_cols; inx++)
	{
	  dbe_column_t * col;
	  if (inx == n_keys)
	    rep_printf (("-->"));
	  else if (inx)
	    rep_printf (", ");
	  col = sch_id_to_col (wi_inst.wi_schema, hsi->hsi_col_ids[inx]);
	  rep_printf (" %s ", col ? col->col_name : "xx");
	}
#ifdef NEW_HASH
      rep_printf ("\n     %d pages " BOXINT_FMT " entries %d reuses %d busy %d src pages %s %X %X\n",
		  it_remap_count (it),
	  it->it_hi->hi_count,
	  it->it_hi_reuses,
	  it->it_ref_count,
	  (it->it_hi->hi_source_pages ? it->it_hi->hi_source_pages->ht_count : -1),
	  (it->it_shared == HI_OK ? "OK" : it->it_shared == HI_FILL ? "FILL" : "BUST"),
	  ((unsigned int) it->it_hi->hi_lock_mode),
	  ((unsigned int) it->it_hi->hi_isolation));
#else
      rep_printf ("\n     %d pages %d entries %d reuses %d busy %s \n",
	  0,
	  it->it_hi->hi_count,
	  it->it_hi_reuses,
	  it->it_ref_count,
	  it->it_shared == HI_OK ? "OK" : it->it_shared == HI_FILL ? "FILL" : "BUST");
#endif
    }
  rep_printf ("\n");
  mutex_leave (hash_index_cache.hic_mtx);
}


void
key_status (const void *k_id, void *k_key)
{
  dbe_key_t *key = (dbe_key_t *) k_key;
  if (strncmp (key->key_table->tb_name, "DB.DBA.SYS_", 11) == 0)
    return;
  if (!key->key_touch || !key->key_read)
    return;
  rep_printf ("%-18s %-19s %7ld %7ld %4ld%% %7ld %7ld %3ld%% %ld\n",
      key->key_table->tb_name,
      key->key_name,
      key->key_touch,
      key->key_read,
      (key->key_read * 100) / (key->key_touch + 1),
      key->key_lock_set,
      key->key_lock_wait,
      (key->key_lock_wait * 100) / (key->key_lock_set + 1),
      key->key_deadlocks);
}


void
key_stats (void)
{
  rep_printf ("Index Usage:\nTable	      Index	       Touches   Reads %Miss   Locks   Waits   %W n-dead\n");
  maphash (key_status, wi_inst.wi_schema->sc_id_to_key);
}


#define mutex_try_enter(m) \
  (mutex_enter (m), 1)

semaphore_t * ps_sem;

void
st_collect_ps_info (dk_set_t * arr)
{
  long time_now = get_msec_real_time ();
  dk_set_t clients;

  mutex_enter (thread_mtx);
  clients = srv_get_logons ();
  DO_SET (dk_session_t *, ses, &clients)
    {
      if (ses)
	{
	  client_connection_t *cli = DKS_DB_DATA (ses);
	  if (cli)
	    {
	      id_hash_iterator_t it;
	      srv_stmt_t **stmt;
	      caddr_t *text;
	      if (mutex_try_enter (cli->cli_mtx))
		{
		  id_hash_iterator (&it, cli->cli_statements);
		  while (hit_next (&it, (char **) & text, (char **) & stmt))
		    {
		      caddr_t * inst = (caddr_t *) (*stmt)->sst_inst;
		      if ((*stmt)->sst_start_msec && inst && (*stmt)->sst_query &&
			  (*stmt)->sst_inst->qi_trx && (*stmt)->sst_inst->qi_trx->lt_threads)
			{
			  dk_set_push (arr, box_string ((*stmt)->sst_query->qr_text));
			  dk_set_push (arr, box_num (time_now - (*stmt)->sst_start_msec));
			}
		    }
		  LEAVE_CLIENT (cli);
		}
	      else
		{
		  dk_set_push (arr, box_string (" client not available, pending compile, time shown is since last exec"));
		  dk_set_push (arr, box_num (time_now - (*stmt)->sst_start_msec));
		}

	    }
	}
    }
  END_DO_SET ();
  mutex_leave (thread_mtx);
  semaphore_leave (ps_sem);
}

char *product_version_string ()
{
  static char buf[1000] = "\0";
  if ('\0' == buf[0])
    snprintf (buf, sizeof (buf),
      "%s%.500s Server (%s%s Edition) Version %s%s as of %s",
      PRODUCT_DBMS, build_special_server_model,
#ifdef OEM_BUILD
      "OEM ",
#else
      "",
#endif
      ((build_thread_model[0] == '-' && build_thread_model[1] == 'f') ?
        "Lite" :
        "Enterprise" ),
      DBMS_SRV_VER, build_thread_model, build_date );
  return buf;
}

long
get_total_sys_mem ()
{
#if defined (linux) || defined (SOLARIS)
    long pages = sysconf(_SC_PHYS_PAGES);
    long page_size = sysconf(_SC_PAGE_SIZE);
    return pages * page_size;
#elif defined (__APPLE__)
    int mib[2];
    long physical_memory;
    size_t length;

    mib[0] = CTL_HW;
    mib[1] = HW_MEMSIZE;
    length = sizeof(long);
    sysctl(mib, 2, &physical_memory, &length, NULL, 0);
    return physical_memory;
#elif defined (WIN32)
    MEMORYSTATUSEX status;
    status.dwLength = sizeof (status);
    GlobalMemoryStatusEx (&status);
    return status.ullTotalPhys;
#else
    return 0;
#endif
}

extern int process_is_swapping;

extern int64 dk_n_allocs;
extern int64 dk_n_free;
extern int64 dk_n_nosz_free;
extern int64 dk_n_bytes;
size_t http_threads_mem_report ();
size_t dk_alloc_global_cache_total ();

void
mem_status_report ()
{
  char buf[1024];
  size_t wsc = http_threads_mem_report ();
  size_t gsz = dk_alloc_global_cache_total ();
  mp_map_count_print (buf, sizeof (buf));
  rep_printf ("Memory:\n");
  rep_printf ("%s", buf);
  rep_printf ("n-alloc: %Ld n-free: %Ld delta: %Ld n-bytes: %Ld nosz-free: %Ld\n", dk_n_allocs, dk_n_free, dk_n_allocs - dk_n_free, dk_n_bytes, dk_n_nosz_free);
  rep_printf ("ws mem cache: %Ld global cache: %Ld\n", wsc, gsz);
}

void
status_report (const char * mode, query_instance_t * qi)
{
  dk_set_t clients;
  int gen_info = 1, cl_mode = CLST_SUMMARY;
  if (!stricmp (mode, "clsrv"))
    {
      cl_srv_status ();
      return;
    }
  else if (!stricmp (mode, "exec"))
    {
      bif_exec_status ();
      return;
    }
  else if (!stricmp (mode, "cluster_d"))
    {
      gen_info = 0;
      cl_mode = CLST_DETAILS;
    }
  else if (!stricmp (mode, "memory"))
    {
      mem_status_report ();
      return;
    }
  else   if (!stricmp (mode, "cluster"))
    gen_info = 0;

  ASSERT_OUTSIDE_TXN;

  if (gen_info)
    {
      rep_printf ("%s%.500s Server\n", PRODUCT_DBMS, build_special_server_model);
      rep_printf ("Version " DBMS_SRV_VER "%s for %s as of %s \n",
		  build_thread_model, build_opsys_id, build_date);
    }
  if (!st_started_since_year)
    {
      char dt[DT_LENGTH];
      TIMESTAMP_STRUCT ts;
      memset (dt, 0, sizeof (dt));
      time_t_to_dt (st_started_since, 0, dt);
      dt_to_timestamp_struct (dt, &ts);
      st_started_since_year = ts.year;
      st_started_since_month = ts.month;
      st_started_since_day = ts.day;
      st_started_since_hour = ts.hour;
      st_started_since_minute = ts.minute;
    }

  if (gen_info)
    {
      rep_printf ("Started on: %04d-%02d-%02d %02d:%02d GMT%+d\n",
		  st_started_since_year, st_started_since_month, st_started_since_day,
	  st_started_since_hour, st_started_since_minute, dt_local_tz / 60);
    }
  if (!gen_info)
    return;
  if (lite_mode)
    rep_printf ("Lite Mode\n");
  process_status_report ();
  dbms_status_report ();
  st_chkp_mapback_pages = 0 /* cpt_count_mapped_back () */;
  rep_printf ("Checkpoint Remap %ld pages, %ld mapped back. %ld s atomic time.\n",
	      wi_inst.wi_master->dbs_cpt_remap->ht_count,
      st_chkp_mapback_pages, atomic_cp_msecs / 1000);
  st_chkp_remap_pages = wi_inst.wi_master->dbs_cpt_remap->ht_count;
  wi_storage_report ();
  srv_lock_report (mode);
  if (strchr (mode, 'c'))
    {
      dk_set_t set = NULL;
      mutex_enter (thread_mtx);
      clients = srv_get_logons ();
      st_cli_n_current_connections = dk_set_length (clients);
      DO_SET (dk_session_t *, ses, &clients)
	{
          if (ses)
	    cli_status_report (ses);
	}
      END_DO_SET ();
      mutex_leave (thread_mtx);
      dk_set_free (clients);
      if (!process_is_swapping)
	{
	  PrpcSelfSignal ((self_signal_func) st_collect_ps_info, (caddr_t)&set);
	  semaphore_enter (ps_sem);
	  rep_printf ("\n\nRunning Statements:\n%12.12s Text\n", "Time (msec)");
	  DO_SET (caddr_t, data, &set)
	    {
	      if (DV_TYPE_OF (data) == DV_C_STRING)

		rep_printf ("%.80s\n", data);
	      else
		rep_printf ("%12ld ", unbox (data));
	      dk_free_box (data);
	    }
	  END_DO_SET ();
	  dk_set_free (set);
	  set = NULL;
	}
      else
	{
	  rep_printf ("\n\nProcess is swapping cannot get client status report.");
	}
    }
  if (strchr (mode, 'k'))
    key_stats ();
  if (strchr (mode, 'h'))
    hic_status ();
  ASSERT_OUTSIDE_TXN;
}


caddr_t
bif_status (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char * mode = BOX_ELEMENTS (args) > 0 ? bif_string_arg (qst, args, 0, "status") : "dhrcl";
/*  caddr_t cli_ws = (caddr_t) ((query_instance_t *)qst)->qi_client->cli_ws;
  if (!cli_ws)
    {*/
      trset_start (qst);
      status_report (mode, (query_instance_t *) qst);
      trset_end ();
/*    }*/


  return NULL;
}

int32 enable_mt_ft_inx = 1;
int32 disable_rdf_init = 0;
extern int32 enable_pg_card;
long vdb_attach_autocommit = 1;
static long my_thread_num_total;
static long my_thread_num_wait;
static long my_thread_num_dead;
static long my_thread_sched_preempt;
static long my_fd_setsize = FD_SETSIZE;
static char * my_bp_prefix = bp_ctx.db_bp_prfx;
static long my_case_mode;
static long my_lite_mode;
static long st_has_vdb =
  0;
char st_os_user_name[512];
static char *_st_os_user_name = &st_os_user_name[0];
extern long srv_cpu_count;
extern int32 col_seg_max_bytes;
extern int32 col_seg_max_rows;



stat_desc_t stat_descs [] =
{
    {"main_bufs", (long *)&main_bufs, SD_INT32},
    {"st_has_vdb", &st_has_vdb, NULL},
    {"disk_reads", (long *)&disk_reads, NULL},
    {"disk_releases", &disk_releases, NULL},
    {"disk_writess", &disk_writes, NULL},
    {"read_cum_time", &read_cum_time, NULL},
    {"lock_deadlocks", &lock_deadlocks, NULL},
    {"lock_2r1w_deadlocks", &lock_2r1w_deadlocks, NULL},
    {"lock_killed_by_force", &lock_killed_by_force, NULL},
    {"lock_waits", &lock_waits, NULL},
    {"lock_enters", &lock_enters, NULL},
    {"lock_leaves", &lock_leaves, NULL},
    {"tc_try_land_write",  &tc_try_land_write, NULL},
    {"tc_dp_changed_while_waiting_mtx", &tc_dp_changed_while_waiting_mtx, NULL},
    {"tc_try_land_reset",  &tc_try_land_reset, NULL},
    {"tc_up_transit_parent_change", &tc_up_transit_parent_change, NULL},
    {"tc_dive_split",  &tc_dive_split, NULL},
    {"tc_dtrans_split",  &tc_dtrans_split, NULL},
    {"tc_up_transit_wait",  &tc_up_transit_wait, NULL},
    {"tc_double_deletes",  &tc_double_deletes, NULL},
    {"tc_delete_parent_waits",  &tc_delete_parent_waits, NULL},
    {"tc_wait_trx_self_kill",  &tc_wait_trx_self_kill, NULL},
    {"tc_read_wait_while_ra_finding_buf", &tc_read_wait_while_ra_finding_buf, NULL},
    {"tc_split_while_committing",  &tc_split_while_committing, NULL},
    {"tc_rb_code_non_unique",  &tc_rb_code_non_unique, NULL},
    {"tc_set_by_pl_wait",  &tc_set_by_pl_wait, NULL},
    {"tc_split_2nd_read",  &tc_split_2nd_read, NULL},
    {"tc_read_wait_decoy", &tc_read_wait_decoy, NULL},
    {"tc_read_wait",  &tc_read_wait, NULL},
    {"tc_write_wait",  &tc_write_wait, NULL},
    {"tc_cl_deadlocks", &tc_cl_deadlocks, NULL},
    {"tc_cl_wait_queries", &tc_cl_wait_queries, NULL},
    {"tc_cl_keep_alives", &tc_cl_keep_alives, NULL},
    {"tc_cl_branch_wanted_queries", &tc_cl_branch_wanted_queries, NULL},
    {"tc_cl_consensus_rollback", &tc_cl_consensus_rollback, NULL},
    {"tc_cl_consensus_commit", &tc_cl_consensus_commit, NULL},
    {"tc_cl_consensus_deferred", &tc_cl_consensus_deferred, NULL},

    {"tc_cl_branch_missed_rb", &tc_cl_branch_missed_rb, NULL},
    {"tc_cl_keep_alive_timeouts", &tc_cl_keep_alive_timeouts, NULL},
    {"tc_cl_commit_resend", &tc_cl_commit_resend, NULL},
    {"tc_cl_disconnect", &tc_cl_disconnect, NULL},
    {"tc_cl_disconnect_in_clt", &tc_cl_disconnect_in_clt, NULL},
    {"tc_dfg_coord_pause", &tc_dfg_coord_pause, NULL},
    {"tc_dfg_more", &tc_dfg_more, NULL},

    {"tc_cl_kill_1pc", &tc_cl_kill_1pc, NULL},
    {"tc_cl_kill_2pc", &tc_cl_kill_2pc, NULL},
    {"tc_atomic_wait_2pc", &tc_atomic_wait_2pc, NULL},
    {"tc_cl_alt_interface", &tc_cl_alt_interface, NULL},
    {"tc_anytime_early_flush", &tc_anytime_early_flush, NULL},
    {"read_block_usec", &read_block_usec, NULL},
    {"write_block_usec", &write_block_usec, NULL},
    {"tc_qp_thread", &tc_qp_thread, NULL},
    {"strses_file_reads", &strses_file_reads, NULL},
    {"strses_file_writes", &strses_file_writes, NULL},
    {"strses_file_seeks", &strses_file_seeks, NULL},
    {"strses_file_wait_msec", &strses_file_wait_msec, NULL},
    {"tc_dive_would_deadlock", &tc_dive_would_deadlock, NULL},
    {"tc_get_buffer_while_stat", &tc_get_buffer_while_stat, NULL},
    {"tc_bp_wait_flush", &tc_bp_wait_flush, NULL},
    {"tc_page_fill_hash_overflow", &tc_page_fill_hash_overflow, NULL},
    {"tc_autocompact_split", &tc_autocompact_split, NULL},
    {"tc_key_sample_reset", &tc_key_sample_reset, NULL},
    {"tc_part_hash_join", &tc_part_hash_join, NULL},
    {"tc_pl_moved_in_reentry", &tc_pl_moved_in_reentry, NULL},
    {"tc_enter_transiting_bm_inx", &tc_enter_transiting_bm_inx, NULL},
    {"tc_geo_delete_retry", &tc_geo_delete_retry, NULL},
    {"tc_geo_delete_missed", &tc_geo_delete_missed, NULL},
    {"tc_aio_seq_write", &tc_aio_seq_write, NULL},
    {"tc_aio_seq_read", &tc_aio_seq_read, NULL},
    {"tc_read_absent_while_finalize", &tc_read_absent_while_finalize, NULL},
    {"tc_fix_outdated_leaf_ptr", &tc_fix_outdated_leaf_ptr, NULL},
    {"tc_bm_split_left_separate_but_no_split", &tc_bm_split_left_separate_but_no_split, NULL},
    {"tc_aq_sleep", &tc_aq_sleep, NULL},
    {"tc_root_image_miss", &tc_root_image_miss, NULL},
    {"tc_root_image_ref_deleted", &tc_root_image_ref_deleted, NULL},
    {"tc_uncommit_cpt_page", &tc_uncommit_cpt_page, NULL},
    {"tc_root_write", &tc_root_write, NULL},
    {"tc_unregister_enter", &tc_unregister_enter, NULL},
    {"tc_root_cache_miss", &tc_root_cache_miss, NULL},


    {"tc_initial_while_closing", &tc_initial_while_closing , NULL},
    {"tc_initial_while_closing_died", &tc_initial_while_closing_died , NULL},
    {"tc_client_dropped_connection", &tc_client_dropped_connection , NULL},
    {"tc_no_client_in_tp_data", &tc_no_client_in_tp_data , NULL},
    {"tc_bp_get_buffer", &tc_bp_get_buffer , NULL},

    {"tc_bp_get_buffer_loop", &tc_bp_get_buffer_loop , NULL},

    {"tc_unused_read_aside", &tc_unused_read_aside, NULL},
    {"tc_adjust_batch_sz", &tc_adjust_batch_sz, NULL},
    {"tc_cum_batch_sz", &tc_cum_batch_sz, NULL},
    {"tc_no_mem_for_longer_batch", &tc_no_mem_for_longer_batch, NULL},
    {"tc_slow_temp_lookup", &tc_slow_temp_lookup, NULL},
    {"tc_slow_temp_insert", &tc_slow_temp_insert, NULL},
    {"tc_dc_max_alloc", &tc_dc_max_alloc, NULL},
    {"tc_dc_default_alloc", &tc_dc_default_alloc, NULL},
    {"tc_dc_alloc", &tc_dc_alloc, NULL},
    {"tc_dc_size", &tc_dc_size, NULL},
    {"tc_dc_extend", &tc_dc_extend, NULL},
    {"tc_dc_extend_values", &tc_dc_extend_values, NULL},
    {"mp_large_in_use", (long *)&mp_large_in_use, NULL},
    {"mp_max_large_in_use", (long *)&mp_max_large_in_use, NULL},
    {"mp_mmap_clocks", &mp_mmap_clocks, NULL},
    {"tc_read_aside", &tc_read_aside, NULL},
    {"tc_merge_reads", &tc_merge_reads, NULL},
    {"tc_merge_read_pages", &tc_merge_read_pages, NULL},
    {"ra_count", &ra_count, NULL},
    {"ra_pages", &ra_pages, NULL},
    {"tc_first_free_replace", &tc_first_free_replace , NULL},
    {"tc_hi_lock_new_lock", &tc_hi_lock_new_lock , NULL},
    {"tc_hi_lock_old_dp_no_lock", &tc_hi_lock_old_dp_no_lock , NULL},
    {"tc_hi_lock_old_dp_no_lock_deadlock", &tc_hi_lock_old_dp_no_lock_deadlock , NULL},
    {"tc_hi_lock_old_dp_no_lock_put_lock", &tc_hi_lock_old_dp_no_lock_put_lock , NULL},
    {"tc_hi_lock_lock", &tc_hi_lock_lock , NULL},
    {"tc_hi_lock_lock_deadlock", &tc_hi_lock_lock_deadlock , NULL},
    {"tc_write_cancel", &tc_write_cancel , NULL},
    {"tc_write_scrapped_buf", &tc_write_scrapped_buf , NULL},
    {"tc_serializable_land_reset", &tc_serializable_land_reset , NULL},
    {"tc_dive_cache_compares", &tc_dive_cache_compares , NULL},
    {"tc_desc_serial_reset", &tc_desc_serial_reset , NULL},
    {"tc_dp_set_parent_being_read", &tc_dp_set_parent_being_read , NULL},
    {"tc_reentry_split", &tc_reentry_split , NULL},
    {"tc_kill_closing", &tc_kill_closing , NULL},
    {"tc_get_buf_failed", &tc_get_buf_failed , NULL},

    {"tc_release_pl_on_deleted_dp", &tc_release_pl_on_deleted_dp, NULL},
    {"tc_release_pl_on_absent_dp", &tc_release_pl_on_absent_dp, NULL},
    {"tc_cpt_lt_start_wait", &tc_cpt_lt_start_wait, NULL},
    {"tc_cpt_rollback", &tc_cpt_rollback, NULL},
    {"tc_wait_for_closing_lt", &tc_wait_for_closing_lt, NULL},
    {"tc_pl_non_owner_wait_ref_deld", &tc_pl_non_owner_wait_ref_deld, NULL},
    {"tc_pl_split", &tc_pl_split, NULL},
    {"tc_pl_split_multi_owner_page", &tc_pl_split_multi_owner_page, NULL},
    {"tc_pl_split_while_wait", &tc_pl_split_while_wait, NULL},
    {"tc_insert_follow_wait", &tc_insert_follow_wait, NULL},
    {"tc_history_itc_delta_wait", &tc_history_itc_delta_wait, NULL},
    {"tc_page_wait_reset", &tc_page_wait_reset, NULL},

    {"tc_posthumous_lock", &tc_posthumous_lock, NULL},
    {"tc_finalize_while_being_read", &tc_finalize_while_being_read, NULL},
    {"tc_rollback_cpt_page", &tc_rollback_cpt_page, NULL},
    {"tc_dive_cache_hits", &tc_dive_cache_hits, NULL},
    {"tc_deadlock_win_get_lock", &tc_deadlock_win_get_lock, NULL},
    {"tc_double_deadlock", &tc_double_deadlock, NULL},
    {"tc_update_wait_move", &tc_update_wait_move, NULL},

    {"tc_blob_read", &tc_blob_read, NULL},
    {"tc_blob_write", &tc_blob_write, NULL},
    {"tc_blob_ra", &tc_blob_ra, NULL},
    {"tc_blob_ra_size", &tc_blob_ra_size, NULL},

    {"tc_cpt_rollback_retry", &tc_cpt_rollback_retry, NULL},
    {"tc_repl_cycle", &tc_repl_cycle, NULL},
    {"tc_repl_connect_quick_reuse", &tc_repl_connect_quick_reuse, NULL},
    {"tc_no_thread_kill_idle", &tc_no_thread_kill_idle, NULL},
    {"tc_no_thread_kill_vdb", &tc_no_thread_kill_vdb, NULL},
    {"tc_no_thread_kill_running", &tc_no_thread_kill_running, NULL},
    {"tc_deld_row_rl_rb", &tc_deld_row_rl_rb, NULL},
    {"tc_pg_write_compact", &tc_pg_write_compact, NULL},
    {"tft_random_seek", &tft_random_seek, NULL},
    {"tft_seq_seek", &tft_seq_seek, NULL},

    {"tws_connections", &tws_connections , NULL},
    {"tws_requests", &tws_requests , NULL},
    {"tws_1_1_requests", &tws_1_1_requests , NULL},
    {"tws_slow_keep_alives", &tws_slow_keep_alives , NULL},
    {"tws_immediate_reuse", &tws_immediate_reuse , NULL},
    {"tws_slow_reuse", &tws_slow_reuse , NULL},
    {"tws_accept_queued", &tws_accept_queued , NULL},
    {"tws_accept_requeued", &tws_accept_requeued , NULL},
    {"tws_keep_alive_ready_queued", &tws_keep_alive_ready_queued , NULL},
    {"tws_early_timeout", &tws_early_timeout, NULL},
    {"tws_disconnect_while_check_in", &tws_disconnect_while_check_in, NULL},
    {"tws_done_while_check_in", &tws_done_while_check_in, NULL},
    {"tws_cancel", &tws_cancel, NULL},

    {"tws_cached_connections_in_use", &tws_cached_connections_in_use , NULL},
    {"tws_cached_connections", &tws_cached_connections , NULL},
    {"tws_cached_connection_hits", &tws_cached_connection_hits , NULL},
    {"tws_cached_connection_miss", &tws_cached_connection_miss , NULL},
    {"tws_bad_request", &tws_bad_request , NULL},

    {"vt_batch_size_limit", &vt_batch_size_limit, NULL},

    {"prof_avg_exec", (long *) &prof_avg_exec, NULL},
    {"prof_n_exec", (long *) &prof_n_exec, NULL},
    {"prof_compile_time", (long *) &prof_compile_time, NULL},

    {"st_dbms_name", NULL, &st_dbms_name},
    {"st_dbms_ver", NULL, &st_dbms_ver},
    {"st_build_thread_model", NULL, &build_thread_model},
    {"st_build_opsys_id", NULL, &build_opsys_id},
    {"st_build_date", NULL, &build_date},

    {"st_proc_served", &st_proc_served, NULL},
    {"st_proc_active", &st_proc_active, NULL},
    {"st_proc_running", &st_proc_running, NULL},
    {"st_proc_queued_req", &st_proc_queued_req, NULL},
    {"st_proc_brk", (long *)&st_proc_brk, NULL},

    {"st_db_file_size", NULL, &st_db_file_size},
    {"st_db_pages", &st_db_pages, NULL},
    {"st_db_page_size", &st_db_page_size, NULL},
    {"st_db_page_data_size", &st_db_page_data_size, NULL},
    {"st_db_free_pages", &st_db_free_pages, NULL},
    {"st_db_buffers", &st_db_buffers, NULL},
    {"st_db_used_buffers", &st_db_used_buffers, NULL},
    {"st_db_dirty_buffers", &st_db_dirty_buffers, NULL},
    {"st_db_wired_buffers", &st_db_wired_buffers, NULL},
    {"st_db_disk_read_avg", &st_db_disk_read_avg, NULL},
    {"st_db_disk_read_pct", &st_db_disk_read_pct, NULL},
    {"st_db_disk_read_last", &st_db_disk_read_last, NULL},
    {"st_db_disk_read_aheads", &st_db_disk_read_aheads, NULL},
    {"st_db_disk_read_ahead_batch", &st_db_disk_read_ahead_batch, NULL},
    {"st_db_disk_second_reads", &st_db_disk_second_reads, NULL},
    {"st_db_disk_in_while_read", &st_db_disk_in_while_read, NULL},
    {"st_db_disk_mt_write", NULL, &st_db_disk_mt_write},
    {"st_db_log_name", NULL, &st_db_log_name},
    {"st_db_log_length", NULL, &st_db_log_length},
    {"st_db_temp_pages", &st_db_temp_pages, NULL},
    {"st_db_temp_free_pages", &st_db_temp_free_pages, NULL},

    {"st_cli_connects", &srv_connect_ctr, NULL},
    {"st_cli_max_connected", &srv_max_clients, NULL},
    {"st_cli_n_current_connections", &st_cli_n_current_connections, NULL},
    {"st_cli_n_http_threads", (long *)&http_threads, SD_INT32},

    {"st_rpc_stat", NULL, &st_rpc_stat},
    {"st_inx_pages_changed", &isp_r_delta, NULL},
    {"st_inx_pages_new", &isp_r_new, NULL},

    {"st_chkp_remap_pages", &st_chkp_remap_pages, NULL},
    {"st_chkp_mapback_pages", &st_chkp_mapback_pages, NULL},
    {"st_chkp_atomic_time", &st_chkp_atomic_time, NULL},
    {"st_chkp_autocheckpoint", (long *) &cfg_autocheckpoint, NULL},
    {"st_chkp_last_checkpointed", (long *) &checkpointed_last_time, NULL},

    {"st_started_since_year", &st_started_since_year, NULL},
    {"st_started_since_month", &st_started_since_month, NULL},
    {"st_started_since_day", &st_started_since_day, NULL},
    {"st_started_since_hour", &st_started_since_hour, NULL},
    {"st_started_since_minute", &st_started_since_minute, NULL},

    {"st_sys_ram", &st_sys_ram, NULL},

    {"prof_on", &prof_on, NULL},
    {"prof_start_time", &prof_start_time, NULL},

    {"fe_replication_support", &fe_replication_support, NULL},

    {"vdb_attach_autocommit", &vdb_attach_autocommit, NULL},
    {"vdb_stat_refresh_disabled", &cfg_disable_vdb_stat_refresh, NULL},
    {"vsp_in_dav_enabled", &vsp_in_dav_enabled, NULL},

    {"dbev_enable", &dbev_enable, NULL},
    {"sql_encryption_on_password", &cli_encryption_on_password, NULL},

    {"blob_releases", &blob_releases, NULL},
    {"blob_releases_noread", &blob_releases_noread, NULL},
    {"blob_releases_dir", &blob_releases_dir, NULL},

    /* Threading values */
    {"thr_thread_num_total", &my_thread_num_total, NULL},
    {"thr_thread_num_wait", &my_thread_num_wait, NULL},
    {"thr_thread_num_dead", &my_thread_num_dead, NULL},
    {"thr_thread_sched_preempt", &my_thread_sched_preempt, NULL},

    {"thr_cli_running", &thr_cli_running, NULL},
    {"thr_cli_waiting", &thr_cli_waiting, NULL},
    {"thr_cli_vdb", &thr_cli_vdb, NULL},

    {"sqlc_add_views_qualifiers", &sqlc_add_views_qualifiers, NULL},

    {"db_ver_string", NULL, &db_version_string},
    {"db_max_col_bytes", &db_max_col_bytes, NULL},
    {"db_sizeof_wide_char", &db_sizeof_wide_char, NULL},

    {"st_host_name", NULL, &dns_host_name},
    {"st_cpu_count", &srv_cpu_count, NULL},
    {"st_default_language", NULL, &server_default_language_name},

    {"st_os_user_name", NULL, &_st_os_user_name},

    {"__internal_first_id", &first_id, NULL},
    {"st_os_fd_setsize", &my_fd_setsize, NULL},
    {"st_case_mode", &my_case_mode, NULL},
    {"enable_qp", (long *)&enable_qp, SD_INT32},
    {"cl_run_local_only", (long *)&cl_run_local_only, SD_INT32},
    {"cluster_enable", (long *)&cluster_enable, SD_INT32},
    {"cl_master_host", (long *)&local_cll.cll_master_host, SD_INT32},
    {"cl_max_host", (long *)&local_cll.cll_max_host, SD_INT32},
    {"cl_stage", (long *)&cl_stage, SD_INT32},
    {"in_log_replay", (long *)&in_log_replay, SD_INT32},
    {"cl_log_from_sync", (long *)&cl_log_from_sync, SD_INT32},
    {"cl_this_host", (long *)&local_cll.cll_this_host, SD_INT32},
    {"cl_n_hosts", (long *)&cl_n_hosts, SD_INT32},
    {"cl_cum_messages", (long *)&cl_cum_messages, SD_INT64},
    {"cl_cum_bytes", (long *)&cl_cum_bytes, SD_INT64},
    {"cl_batch_bytes", (long *)&cl_batch_bytes, SD_INT32},
    {"iri_range_size", (long *)&iri_range_size, SD_INT32},
    {"cl_req_batch_size", (long *)&cl_req_batch_size, SD_INT32},
    {"db_exists", (long *)&db_exists, SD_INT32},
    {"st_lite_mode", &my_lite_mode, NULL},
    {"db_default_columnstore", (long *)&enable_col_by_default, SD_INT32},
    {"enable_col_by_default", (long *)&enable_col_by_default, SD_INT32},
    {"enable_mt_ft_inx", (long *)&enable_mt_ft_inx, SD_INT32},
    {"disable_rdf_init", (long *)&disable_rdf_init, SD_INT32},

    /* backup vars */
    {"backup_prefix_name", NULL, &my_bp_prefix},
    {"backup_file_index", (long *)&bp_ctx.db_bp_num, NULL},
    {"backup_dir_index", (long *)&bp_ctx.db_bp_index, NULL},
    {"backup_dir_bytes", (long *)&bp_ctx.db_bp_wr_bytes, NULL},
    {"backup_processed_pages", (long *)&bp_ctx.db_bp_pages, NULL},

    /* sparql vars */
    {"sparql_result_set_max_rows", &sparql_result_set_max_rows, NULL},
    {"sparql_max_mem_in_use", &sparql_max_mem_in_use, NULL},
    {"rdf_create_graph_keywords", &rdf_create_graph_keywords, SD_INT32},
    {"rdf_query_graph_keywords", &rdf_query_graph_keywords, SD_INT32},
    {"enable_vec", (long *)&enable_vec, SD_INT32},
    {"srv_init", (long *)&in_srv_global_init, SD_INT32},
    {"ac_real_time", (long *)&ac_real_time, SD_INT32},
    {"ac_cpu_time", (long *)&ac_cpu_time, SD_INT32},
    {"ac_n_times", (long *)&ac_n_times, SD_INT32},
    {"col_ac_last_duration", (long *)&col_ac_last_duration, SD_INT32},
    {"col_ins_error", (long *)&col_ins_error, SD_INT32},
    {"cl_rdf_inf_inited", (long *)&cl_rdf_inf_inited, SD_INT32},
    {NULL, NULL, NULL}
};


stat_desc_t dbf_descs [] =
  {
    {"dbf_no_disk", &dbf_no_disk, NULL},
    {"dbf_2pc_prepare_wait", &dbf_2pc_prepare_wait, NULL},
    {"dbf_2pc_wait", &dbf_2pc_wait, NULL},
    {"dbf_branch_transact_wait", &dbf_branch_transact_wait, NULL},
    {"dbf_log_no_disk", &dbf_log_no_disk, NULL},
    {"dbf_clop_enter_wait", &dbf_clop_enter_wait, NULL},
    {"dbf_cl_skip_wait_notify", &dbf_cl_skip_wait_notify, NULL},
    {"dbf_cpt_rb", &dbf_cpt_rb, NULL},
    {"cl_no_auto_remove", (long *)&cl_no_auto_remove, SD_INT32},
    {"dbf_cl_blob_autosend_limit", &dbf_cl_blob_autosend_limit, NULL},
    {"dbf_no_sample_timeout", &dbf_no_sample_timeout, NULL},
    {"dbf_fast_cpt", (long *)&dbf_fast_cpt, SD_INT32},
    {"cl_req_batch_size", (long *)&cl_req_batch_size, SD_INT32},
    {"cl_dfg_batch_bytes", (long *)&cl_dfg_batch_bytes, SD_INT32},
    {"cl_res_buffer_bytes", (long *)&cl_res_buffer_bytes, SD_INT32},
    {"cl_batches_per_rpc", (long *)&cl_batches_per_rpc, SD_INT32},
    {"cl_rdf_inf_inited", (long *)&cl_rdf_inf_inited, SD_INT32},
    {"enable_mem_hash_join", (long *)&    enable_mem_hash_join, SD_INT32},
    {"enable_hash_merge", (long *)&enable_hash_merge, SD_INT32},
    {"enable_hash_fill_join", (long *)&enable_hash_fill_join, SD_INT32},
    {"enable_subscore", (long *)&enable_subscore, SD_INT32},
    {"enable_at_print", (long *)&enable_at_print, SD_INT32},
    {"enable_min_card", (long *)&enable_min_card},
    {"enable_distinct_sas", (long *)&enable_distinct_sas, SD_INT32},
    {"hash_join_enable", (long *)&hash_join_enable, SD_INT32},
    {"em_ra_window", (long *)&em_ra_window, SD_INT32},
    {"em_ra_threshold", (long *)&em_ra_threshold, SD_INT32},
    {"em_ra_startup_threshold", (long *)&em_ra_startup_threshold, SD_INT32},
    {"timeout_resolution_sec", (long *)&atomic_timeout.to_sec, SD_INT32},
    {"timeout_resolution_usec", (long *)&atomic_timeout.to_usec, SD_INT32},
    {"ha_rehash_pct", (long *)&ha_rehash_pct, SD_INT32},
    {"c_use_aio", (long *)&c_use_aio, SD_INT32},
    {"callstack_on_exception", &callstack_on_exception, NULL},
    {"enable_vec", (long *)&enable_vec, SD_INT32},
    {"enable_qp", (long *)&enable_qp, SD_INT32},
    {"enable_mt_txn", (long *)&enable_mt_txn, SD_INT32},
    {"enable_mt_transact", (long *)&enable_mt_transact, SD_INT32},
    {"enable_qn_cache", (long *)&enable_qn_cache, SD_INT32},
    {"aq_max_threads", (long *)&aq_max_threads, SD_INT32},
    {"qp_thread_min_usec", (long *)&qp_thread_min_usec, SD_INT32},
    {"qp_range_split_min_rows", (long *)&qp_range_split_min_rows, SD_INT32},
    {"qp_even_if_lock", (long *)&qp_even_if_lock, SD_INT32},
    {"enable_ro_rc", (long *)&enable_ro_rc, SD_INT32},
    {"dc_batch_sz", (long *)&dc_batch_sz, SD_INT32},
    {"dc_max_batch_sz", (long *)&dc_max_batch_sz, SD_INT32},
    {"enable_dyn_batch_sz", (long *)&enable_dyn_batch_sz, SD_INT32},
    {"enable_vec_reuse", (long *)&enable_vec_reuse, SD_INT32},
    {"dc_adjust_batch_sz_min_anytime", (long *)&dc_adjust_batch_sz_min_anytime, SD_INT32},
    {"enable_split_range", (long *)&enable_split_range, SD_INT32},
    {"enable_split_sets", (long *)&enable_split_sets, SD_INT32},
    {"dbf_compress_mask", (long *)&dbf_compress_mask, SD_INT32},
    {"dbf_ce_insert_mask", (long *)&dbf_ce_insert_mask, SD_INT32},
    {"dbf_ce_del_mask", (long *)&dbf_ce_del_mask, SD_INT32},
    {"dbf_col_ins_dbg_log", (long *)&dbf_col_ins_dbg_log, SD_INT32},
    {"dbf_col_del_leaf", (long *)&dbf_col_del_leaf, SD_INT32},
    {"enable_pogs_check", (long *)&enable_pogs_check, SD_INT32},
    {"chash_space_avail", (long *)&chash_space_avail},
    {"chash_per_query_pct", (long *)&chash_per_query_pct, SD_INT32},
    {"enable_chash_gb", (long *)&enable_chash_gb, SD_INT32},
    {"enable_ksp_fast", (long *)&enable_ksp_fast, SD_INT32},
    {"enable_ac", (long *)&enable_ac, SD_INT32},
    {"enable_col_ac", (long *)&enable_col_ac, SD_INT32},
    {"col_ins_error", (long *)&col_ins_error, SD_INT32},
    {"col_seg_max_bytes", (long *)&col_seg_max_bytes, SD_INT32},
    {"col_seg_max_rows", (long *)&col_seg_max_rows, SD_INT32},
    {"cl_ac_interval", (long *)&cl_ac_interval, SD_INT32},
    {"enable_buf_mprotect", (long *)&enable_buf_mprotect, SD_INT32},
    {"cl_no_disable_of_unavailable", (long *)&local_cll.cll_no_disable_of_unavailable, SD_INT32},
    {"dbf_log_fsync", (long *)&dbf_log_fsync, SD_INT32},
    { "cls_rollback_no_finish_if_thread", (long *)&cls_rollback_no_finish_if_thread, SD_INT32},
    {"sqlo_sample_dep_cols", (long *)&sqlo_sample_dep_cols},
    {"default_txn_isolation", (long *)&default_txn_isolation, SD_INT32},
    {"tc_dc_max_alloc", &tc_dc_max_alloc, NULL},
    {"tc_dc_default_alloc", &tc_dc_default_alloc, NULL},
    {"tc_dc_alloc", &tc_dc_alloc, NULL},
    {"tc_dc_size", &tc_dc_size, NULL},
    {"tc_dc_extend", &tc_dc_extend, NULL},
    {"tc_dc_extend_values", &tc_dc_extend_values, NULL},

    {"c_max_large_vec", (long *)&c_max_large_vec, NULL},
    {"cha_max_gb_bytes", (long *)&cha_max_gb_bytes, NULL},
    {"mp_large_reserved", &mp_large_reserved},
    {"mp_max_large_reserved", &mp_max_large_reserved},
    {"mp_large_reserve_limit", &mp_large_reserve_limit},

    {"iri_range_size", (long *)&iri_range_size, SD_INT32},
    { "tn_max_memory",  (long *)&tn_max_memory, NULL},
    {"tn_at_mem_cutoff", (long *)&tn_at_mem_cutoff, NULL},
    {"tn_at_mem_cutoff", (long *)&tn_at_mem_cutoff, NULL},
    {"tn_mem_cutoff", (long *)&tn_mem_cutoff, NULL},
    {"tn_at_card_cutoff", (long *)&tn_at_card_cutoff, NULL},
    {"tn_card_cutoff", (long *)&tn_card_cutoff, NULL},
    {"dbf_max_itc_samples", (long *)&dbf_max_itc_samples, SD_INT32},
    {"enable_mt_ft_inx", (long *)&enable_mt_ft_inx, SD_INT32},
    {"disable_rdf_init", (long *)&disable_rdf_init, SD_INT32},
    {"enable_pg_card", (long *)&enable_pg_card, SD_INT32},
    {"enable_ce_ins_check",  (long *)&enable_ce_ins_check, SD_INT32},
    {"dbf_ignore_uneven_col", (long *)&dbf_ignore_uneven_col, SD_INT32},
    {"c_no_dbg_print", (long *)&c_no_dbg_print, SD_INT32},
    {"dbf_explain_level", (long *)&dbf_explain_level, SD_INT32},
    {"mp_local_rc_sz", (long *)&mp_local_rc_sz, SD_INT32},
    {"dbf_user_1", &dbf_user_1},
    {"dbf_user_2", &dbf_user_2},
#ifdef CACHE_MALLOC
    {"enable_no_free", &enable_no_free, SD_INT32},
#endif
    {"enable_rdf_box_const", &enable_rdf_box_const, SD_INT32},
    {NULL, NULL, NULL}
  };


caddr_t
dbs_list ()
{
  dk_set_t res = NULL;
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
    {
      if (dbs->dbs_slices)
	continue;
      dk_set_push (&res, (void*)box_dv_short_string (dbs->dbs_name));
    }
  END_DO_SET ();
  return list_to_array (res);
}


caddr_t
bif_ext_stat (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * res;
  dp_addr_t n, inx;
  caddr_t dn = bif_string_arg (qst, args, 0, "ext_stat");
  dbe_storage_t * dbs = wd_storage (wi_inst.wi_master_wd, dn, 0);
  if (!dbs)
    sqlr_new_error ("42000", "DBS..", "No dbs %s", dn);
  n = dbs->dbs_n_pages;
  if (n / EXTENT_SZ > 2047 * 1024)
    n = 2047 * 1024 * EXTENT_SZ;
  if (!dbs->dbs_ext_ts)
    return dk_alloc_box (0, DV_ARRAY_OF_POINTER);
  res = (caddr_t*) dk_alloc_box (sizeof (caddr_t) * n / EXTENT_SZ, DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n; inx += EXTENT_SZ)
    {
      ext_ts_t    cnt = dbs->dbs_ext_ts[inx / EXTENT_SZ];
      res[inx / EXTENT_SZ] = box_num (cnt);
    }
  return (caddr_t)res;
}


caddr_t
bif_ext_em (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  extent_map_t * em;
  caddr_t dn = bif_string_arg (qst, args, 0, "ext_stat");
  dbe_storage_t * dbs = wd_storage (wi_inst.wi_master_wd, dn, 0);
  dp_addr_t dp = bif_long_arg (qst, args, 1, "ext_em");
  if (!dbs)
    sqlr_new_error ("42000", "DBS..", "No dbs %s", dn);
  em = (extent_map_t*)gethash ((void*)(ptrlong) EXT_ROUND (dp), dbs->dbs_dp_to_extent_map);
  if (!em)
    return dk_alloc_box (0, DV_DB_NULL);
  return box_dv_short_string (em->em_name);
}


id_hash_t * sd_hash;

caddr_t
sys_stat_impl (const char *name)
{
  stat_desc_t *sd_arrays[] = {stat_descs, dbf_descs, NULL};
  stat_desc_t **sd_arrays_tail;
  stat_desc_t **place;

  my_thread_num_total = _thread_num_total;
  my_thread_num_wait = _thread_num_wait;
  my_thread_num_dead = _thread_num_dead;
  my_thread_sched_preempt = _thread_sched_preempt;
  my_case_mode  = case_mode;
  my_lite_mode  = lite_mode;
  if (!st_dbms_name_buffer[0])
    snprintf (st_dbms_name_buffer, sizeof (st_dbms_name_buffer),
	  "%s %.500s Server", PRODUCT_DBMS, build_special_server_model);

  if (0 == strcmp ("backup_pages", name))
    return (box_num_nonull (dbs_count_incbackup_pages (wi_inst.wi_master)));

  if (0 == strcmp ("backup_time_stamp", name))
    return (bp_curr_timestamp ());
  if (0 == strcmp ("dbs_list", name))
    return dbs_list ();
  if (0 == strcmp ("backup_last_date", name))
    return (bp_curr_date ());
  if (!sd_hash)
    {
      sd_hash = id_str_hash_create (201);
  for (sd_arrays_tail = sd_arrays; NULL != sd_arrays_tail[0]; sd_arrays_tail++)
    {
      stat_desc_t *sd;
      for (sd = sd_arrays_tail[0]; NULL != sd->sd_name; sd++)
        {
	      id_hash_set (sd_hash, (caddr_t) &sd->sd_name, (caddr_t) &sd);
	    }
	}
    }
  place = (stat_desc_t **)id_hash_get (sd_hash, (caddr_t)&name);
  if (place)
            {
	      stat_desc_t * sd = *place;
              if (SD_INT32 == (char **) sd->sd_str_value)
                return box_num_nonull (*(int32*)sd->sd_value);
              if (SD_INT64 == (char **) sd->sd_str_value)
                return box_num_nonull (*(int64*)sd->sd_value);
              else if (sd->sd_value)
                return (box_num_nonull (*(sd->sd_value)));
              else if (sd->sd_str_value)
                return (box_dv_short_string (*(sd->sd_str_value)));
            }
  return NULL;
}

caddr_t
bif_sys_stat (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "sys_stat");
  caddr_t res = sys_stat_impl (name);
  if (NULL == res)
  sqlr_new_error ("42S22", "SR242", "No system status variable %s", name);
  return res;
}


caddr_t
bif_dbf_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "__dbf_set");
  long v = bif_long_arg (qst, args, 1, "__dbf_set");
  stat_desc_t *sd, **place;
  sec_check_dba ((query_instance_t*)qst, "__dbf_set");
  place = (stat_desc_t**)id_hash_get (sd_hash, (caddr_t)&name);
  if (!place)
    sqlr_new_error ("42000", "SR...", "sys_stat_set, parameter does not exist");


  sd = *place;
  if (SD_INT32 == (char **) sd->sd_str_value)
	    {
	      int32 ov = *((int32*)sd->sd_value);
	      *((int32*)sd->sd_value) = v;
	      return (box_num (ov));
	    }
	  if (sd->sd_value)
	    {
	      long ov = *(sd->sd_value);
	      *(sd->sd_value) = v;
	      return (box_num (ov));
	    }
	  else
	    sqlr_new_error ("42000", "SR...", "sys_stat_set, parameter not settable");
  return NULL; /*dummy*/
}


void
srv_ip (char *ip_addr, size_t max_ip_addr, char *host)
{
#if defined (_REENTRANT) && (defined (linux) || defined (SOLARIS))
  struct hostent ht;
  char buff [4096];
  int herrnop;
#endif
  struct hostent *local;

#if defined (_REENTRANT) && defined (linux)
  gethostbyname_r (host, &ht, buff, sizeof (buff), &local, &herrnop);
#elif defined (_REENTRANT) && defined (SOLARIS)
  local = gethostbyname_r (host, &ht, buff, sizeof (buff), &herrnop);
#else
  local = gethostbyname (host);
#endif
  /* XXX in a feature we should check for AF_INET6 */
  if (local && local->h_addr_list[0] && local->h_addrtype == AF_INET)
    {
      unsigned char addr [4];
      memcpy (addr, (unsigned char *)(local->h_addr_list[0]), sizeof (addr));
      snprintf (ip_addr, max_ip_addr, "%u.%u.%u.%u", addr [0], addr [1], addr [2], addr [3]);
    }
  else
    strcpy_size_ck (ip_addr, "", max_ip_addr);
}

caddr_t
bif_identify_self (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char host [256], pid [64], ip_addr [16]; /* IP address length dependent of AF_INET */

  snprintf (pid, sizeof (pid), "%ld", srv_pid);

  if (0 != gethostname (host, sizeof (host)))
    strcpy_ck (host, "localhost");

  srv_ip (ip_addr, sizeof (ip_addr), host);
  if (0 == strlen (ip_addr) && strcmp (host, "localhost"))
    {
      strcpy_ck (host, dns_host_name);
      srv_ip (ip_addr, sizeof (ip_addr), host);
    }

  return (caddr_t) (list (4,
	box_dv_short_string (host),
	box_dv_short_string (pid),
	box_dv_short_string (ip_addr),
	box_dv_short_string ("")
       ));
}


int32
key_n_buffers (dbe_key_t * key, int dirty)
{
  int ct = 0, inx, inx2;
  for (inx = 0; inx < wi_inst.wi_n_bps; inx++)
    {
      buffer_pool_t * bp = wi_inst.wi_bps[inx];
      for (inx2 = 0; inx2 < bp->bp_n_bufs; inx2++)
	{
	  buffer_desc_t * buf = &bp->bp_bufs[inx2];
	  if (buf->bd_tree && buf->bd_tree->it_key == key
	      && (!dirty || buf->bd_is_dirty))
	    ct++;
	}
    }
  return ct;
}


caddr_t
key_page_list (dbe_key_t * key)
{
  return em_page_list (key->key_fragments[0]->kf_it->it_extent_map, EXT_INDEX);
}


caddr_t
bif_key_stat (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t tb_name = bif_string_arg (qst, args, 0, "sys_stat");
  caddr_t key_name = bif_string_arg (qst, args, 1, "sys_stat");
  caddr_t stat_name = bif_string_arg (qst, args, 2, "sys_stat");
  dbe_table_t *tb = qi_name_to_table (qi, tb_name);
  if (!tb)
    {
      sqlr_new_error ("42S02", "SR243", "No table %s in key_stat", tb_name);
    }
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      if (0 == strcmp (key->key_name, key_name))
	{
	  if (0 == strcmp (stat_name, "touches"))
	    return (box_num (key->key_touch));
	  if (0 == strcmp (stat_name, "reads"))
	    return (box_num (key->key_read));
	  if (0 == strcmp (stat_name, "writes"))
	    return (box_num (key->key_write));
	  if (0 == strcmp (stat_name, "lock_set"))
	    return (box_num (key->key_lock_set));
	  if (0 == strcmp (stat_name, "n_buffers"))
	    return box_num (key_n_buffers (key, 0));
	  if (0 == strcmp (stat_name, "page_list"))
	    return key_page_list (key);

	  if (0 == strcmp (stat_name, "write_wait"))
	    return (box_num (key->key_write_wait - key->key_landing_wait - key->key_pl_wait));
	  /* landing waits and pl waits are also counted in write waits, so subtract here */
	  if (0 == strcmp (stat_name, "read_wait"))
	    return (box_num (key->key_read_wait));
	  if (0 == strcmp (stat_name, "landing_wait"))
	    return (box_num (key->key_landing_wait));
	  if (0 == strcmp (stat_name, "pl_wait"))
	    return (box_num (key->key_pl_wait));

	  if (0 == strcmp (stat_name, "lock_waits"))
	    return (box_num (key->key_lock_wait));
	  if (0 == strcmp (stat_name, "lock_wait_time"))
	    return (box_num (key->key_lock_wait_time));
	  if (0 == strcmp (stat_name, "deadlocks"))
	    return (box_num (key->key_deadlocks));
	  if (0 == strcmp (stat_name, "lock_escalations"))
	    return (box_num (key->key_lock_escalations));
	  if (0 == strcmp (stat_name, "n_landings"))
	    return (box_num (key->key_n_landings));
	  if (0 == strcmp (stat_name, "total_last_page_hits"))
	    return (box_num (key->key_total_last_page_hits));
	  if (0 == strcmp (stat_name, "page_end_inserts"))
	    return (box_num (key->key_page_end_inserts));
	  if (0 == strcmp (stat_name, "n_dirty"))
	    return box_num (key_n_buffers (key, 1));

	  if (0 == strcmp (stat_name, "n_new"))
	    return (box_num (0));

	  if (0 == strcmp (stat_name, "n_pages"))
	    return (box_num (it_remap_count (key->key_fragments[0]->kf_it)));
	  if (0 == strcmp (stat_name, "n_rows"))
	    return (box_num (key->key_table->tb_count));
	  if (0 == strcmp (stat_name, "ac_in"))
	    return (box_num (key->key_ac_in));
	  if (0 == strcmp (stat_name, "ac_out"))
	    return (box_num (key->key_ac_out));
	  if (0 == strcmp (stat_name, "n_est_rows"))
	    {
	      return box_num (tb->tb_count_estimate + tb->tb_count_delta);
	    }
	  if (0 == strcmp (stat_name, "reset"))
	    {
	      key->key_touch = 0;
	      key->key_read = 0;
	      key->key_write = 0;
	      key->key_lock_wait = 0;
	      key->key_lock_wait_time = 0;
	      key->key_deadlocks = 0;
	      key->key_lock_set = 0;
	      key->key_lock_escalations = 0;
	      key->key_page_end_inserts = 0;
	      key->key_write_wait = 0;
	      key->key_read_wait = 0;
	      key->key_landing_wait = 0;
	      key->key_pl_wait = 0;
	      key->key_last_page = 0;
	      key->key_is_last_right_edge = 0;
	      key->key_n_last_page_hits = 0;
	      key->key_total_last_page_hits = 0;
	      key->key_n_landings = 0;
	      key->key_table->tb_count_estimate = DBE_NO_STAT_DATA;
	      key->key_ac_in = 0;
	      key->key_ac_out = 0;
	      return NULL;
	    }
	  sqlr_new_error ("22023", "SR244",
	      "Allowed stat names are touches, reads, lock_set, lock_waits, deadlocks, lock_wait_time, lock_escalations, n_dirty, n_new, n_pages, n_est_rows, n_rows.");
	}
    }
  END_DO_SET();
  sqlr_new_error ("42S12", "SR245", "Index %s not found in key_stat.", key_name);
  return NULL; /*dummy*/
}


caddr_t
bif_col_stat (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long id = bif_long_arg (qst, args, 0, "col_stat");
  caddr_t name = bif_string_arg (qst, args, 1, "col_stat");
  dbe_column_t * col = sch_id_to_column (wi_inst.wi_schema, id);
  if (!col)
    sqlr_new_error ("42000", "ST001", "Bad column id in col_stat");
  if (0 == strcmp (name, "n_distinct"))
    return box_num (col->col_n_distinct);
  if (0 == strcmp (name, "avg_len"))
    return box_num (col->col_avg_len);
  if (0 == strcmp (name, "n_values"))
    return box_num (col->col_count);
  sqlr_new_error ("42000", "ST002", "Bad attribute name in col_stat");
  return NULL;
}


typedef struct qr_time_s
  {
    uint32		qt_cum;
    uint32		qt_n;
    uint32	 qt_n_error;
    caddr_t	qt_title;
  } qr_time_t;

typedef struct time_range_s
  {
    int		tr_max;
    int		tr_n;
  } time_range_t;

#define TIME_N_SLOTS 5
time_range_t prof_under [TIME_N_SLOTS];


#define PROF_MAX_DISTINCT 10000

id_hash_t * prof_stat;
dk_mutex_t * prof_mtx;


long
qt_key (qr_time_t * qt)
{
/* Nice thing here: if unary minus operator applied to unsigned,
   the result is still unsigned. Borland is unhappy...
  return (- qt->qt_cum); */
/* Thus if you want just sort unsigned-s in reverse order, negate them... */
  return (long)(~(qt->qt_cum));
}


#if 0
void
prof_check (qr_time_t ** times, int fill)
{
  dk_hash_t * ht = hash_table_allocate (101);
  int inx;
  for (inx = 0; inx < fill; inx++)
    sethash ((void*) times[inx]->qt_title, ht, (void*) 1);
  if (ht->ht_count != fill)
    GPF_T1 ("repeated distinct items in profile stat");
}
#endif


void
prof_report (void)
{
  long real;
  qr_time_t * qtp;
  caddr_t * kp;
  FILE * out;
  size_t times_len = sizeof (caddr_t)  * prof_stat->ht_inserts;
  qr_time_t ** times = (qr_time_t **) dk_alloc (times_len);
  int fill = 0, inx;
  id_hash_iterator_t hit;
  time_t tnow;
  struct tm *tms;

  time (&tnow);
  ASSERT_IN_MTX (prof_mtx);
  id_hash_iterator (&hit, prof_stat);
  while (hit_next (&hit, (char **) &kp, (char **) &qtp))
    {
      if (qtp->qt_title != *(caddr_t *)kp)
	GPF_T1 ("bad profile stats hash table");
      times[fill++] = qtp;
    }
  if (fill != prof_stat->ht_inserts)
    GPF_T1 ("profile stats hash table inconsistent");
  if (!prof_exec_time || !prof_n_exec)
    return;
  buf_sort ((buffer_desc_t **) times, fill, (sort_key_func_t) qt_key);
  out = fopen ("virtprof.out", "w");
  if (out)
    {
      real = 1 + get_msec_real_time () - prof_start_time;
      if (prof_stat_table == 1)
	{
	  char tmp_buf[1024];
	  tms = localtime (&prof_start_time_st);
	  strftime (tmp_buf, sizeof (tmp_buf), "%Y-%m-%d %H:%M:%S", tms);
	  fprintf (out, "<table id='tim_t' border=\"1\" cellpadding=\"3\" cellspacing=\"0\">");
	  fprintf (out, "<tr><td>Started</td><td id='start_t'>%s</td></tr>\n", tmp_buf);
	  tms = localtime (&tnow);
	  strftime (tmp_buf, sizeof (tmp_buf), "%Y-%m-%d %H:%M:%S", tms);
	  fprintf (out, "<tr><td>End</td><td id='end_t'>%s</td></tr>\n", tmp_buf);
	  fprintf (out, "</table>\n\n");
	  fprintf (out, "<table id='qprof_t' border=\"1\" cellpadding=\"3\" cellspacing=\"0\"><tr><th colspan=\"5\">Query Profile (msec)</th></tr><tr><th>Real</th><th>client wait</th><th>avg conc</th><th>n_execs</th><th>avg exec</th></tr><tr><td>%ld</td><td>%ld</td><td>%4f</td><td>%ld</td><td>%ld</td></tr></table>\n\n",
	      real, prof_exec_time,
	      (float) prof_exec_time / (float)real,
	      prof_n_exec, prof_avg_exec);

	  fprintf (out, "<table id='qprof2_t' border=\"1\" cellpadding=\"3\" cellspacing=\"0\">");
	  for (inx = 0; inx < TIME_N_SLOTS; inx++)
	    {
	      fprintf (out, "<tr><td>%ld %%</td><td>under %d s</td></tr>", (100 *  prof_under[inx].tr_n) / prof_n_exec,
		  prof_under[inx].tr_max / 1000);
	      prof_under[inx].tr_n = 0;
	    }
	  fprintf (out, "</table>\n\n");
	  fprintf (out, "<table id='stmts_t' border=\"1\" cellpadding=\"3\" cellspacing=\"0\"><tr><th>stmts compiled</th><th>Time (msec)</th><th>prepared reused</th></tr>");
	  fprintf (out, "<tr><td>%ld</td><td>%ld</td><td>%ld %%</td></tr></table>\n", prof_n_compile, prof_compile_time,
	      prof_n_reused);

	  fprintf (out, "<table border=\"1\" cellpadding=\"3\" cellspacing=\"0\"><tr><th>%%</th><th>total</th><th>n-times</th><th>n-errors</th></tr>\n");
	  for (inx = 0; inx < fill; inx++)
	    {
	      fprintf (out, "<tr><td>%-3ld%%</td><td>%-8ld</td><td>%-8ld</td><td>%-5ld</td><td>%s</td></tr>\n",
		  (long) (((float)times[inx]->qt_cum * 100) / (float)prof_exec_time),
		  (long) times[inx]->qt_cum, (long) times[inx]->qt_n,
		  (long) times[inx]->qt_n_error, times[inx]->qt_title);
	      dk_free_box (times[inx]->qt_title);
	    }
	  fprintf (out, "</table>\n");
	}
      else
	{
	  fprintf (out, "Query Profile (msec)\nReal %ld, client wait %ld, avg conc %4f n_execs %ld avg exec  %ld \n\n",
	      real, prof_exec_time,
	      (float) prof_exec_time / (float)real,
	      prof_n_exec, prof_avg_exec);

	  for (inx = 0; inx < TIME_N_SLOTS; inx++)
	    {
	      fprintf (out, "%ld %% under %d s\n", (100 *  prof_under[inx].tr_n) / prof_n_exec,
		  prof_under[inx].tr_max / 1000);
	      prof_under[inx].tr_n = 0;
	    }
	  fprintf (out, "\n%ld stmts compiled %ld msec, %ld %% prepared reused.\n", prof_n_compile, prof_compile_time,
	      prof_n_reused);

	  fprintf (out, "\n %%  total n-times n-errors \n");
	  for (inx = 0; inx < fill; inx++)
	    {
	      fprintf (out, "%-3ld%% %-8ld %-8ld %-5ld %s\n",
		  (long) (((float)times[inx]->qt_cum * 100) / (float)prof_exec_time),
		  (long) times[inx]->qt_cum, (long) times[inx]->qt_n,
		  (long) times[inx]->qt_n_error, times[inx]->qt_title);
	      dk_free_box (times[inx]->qt_title);
	    }
	}
      fclose (out);
    }
  id_hash_clear (prof_stat);
  prof_stat->ht_inserts = 0; /* make sure, used as ht count */
  dk_free ((caddr_t) times, times_len);
  prof_start_time = get_msec_real_time ();
  prof_n_exec = 0;
  prof_n_reused = 0;
  prof_exec_time = 0;
  prof_n_compile = 0;
  prof_compile_time = 0;
}


void
qr_prof_title (query_t * qr, char * text, char * str, int max)
{
  /* return substring of query text used to identify the event in profile */
  if (text)
    {
      strncpy (str, text, max - 1);
      str[max - 1] = 0;
      return;
    }
  if (qr->qr_text)
    {
      if ((qn_input_fn) end_node_input == qr->qr_head_node->src_input)
	{
	  /* if proc call, take text up to open parenthesis */
	  char * par = strchr (qr->qr_text, '(');
	  if (par && (((long) (par - qr->qr_text)) < max - 1))
	    {
	      size_t len = par - qr->qr_text;
	      strncpy (str, qr->qr_text, len);
	      str[len] = 0;
	      return;
	    }
	}
      strncpy (str, qr->qr_text, max - 1);
      str[max - 1] = 0;
    }
}


void
prof_exec (query_t * qr, char * text, long msecs, int flags)
{
  int inx;
  prof_exec_time += msecs;
  prof_n_exec++;
  prof_avg_exec = prof_exec_time / prof_n_exec;
  for (inx = 0; inx < TIME_N_SLOTS; inx++)
    {
      if (prof_under[inx].tr_max > msecs)
	{
	  prof_under[inx].tr_n++;
	  break;
	}
    }
  if (prof_stat)
    {
      char str[40];
      char * strp = &str[0];
      qr_time_t * qt;
      str[0] = 0;
      qr_prof_title (qr, text, str, sizeof (str));
      mutex_enter (prof_mtx);
      qt = (qr_time_t *) id_hash_get (prof_stat, (char *) &strp);
      if (qt)
	{
	  qt->qt_n += PROF_EXEC & flags ? 1 : 0;
	  qt->qt_n_error += flags & PROF_ERROR ? 1 : 0;
	  qt->qt_cum += msecs;
	}
      else
	{
	  caddr_t box = box_string (str);
	  qr_time_t qt;
	  qt.qt_n = 1;
	  qt.qt_n_error = flags & PROF_ERROR ? 1 : 0;
	  qt.qt_cum = msecs;
	  qt.qt_title = box;
	  id_hash_set (prof_stat, (caddr_t) &box, (caddr_t) &qt);
	}
      if (prof_stat->ht_inserts > PROF_MAX_DISTINCT)
	prof_report ();
      mutex_leave (prof_mtx);
    }
}


id_hash_t * qn_prof;


extern dk_mutex_t ql_mtx;
extern dk_session_t * ql_file;
extern char * c_query_log_file;


caddr_t
bif_profile_enable (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int n_args;
  if (!prof_mtx)
    {
      if (TIME_N_SLOTS < 5)
	GPF_T;
      prof_under[0].tr_max = 1000;
      prof_under[1].tr_max = 2000;
      prof_under[2].tr_max = 5000;
      prof_under[3].tr_max = 10000;
      prof_under[4].tr_max = 30000;
      prof_mtx = mutex_allocate ();
      qn_prof = id_hash_allocate (101, sizeof (boxint), sizeof (src_stat_t), boxint_hash, boxint_hashcmp);
    }
  mutex_enter (prof_mtx);
  id_hash_clear (qn_prof);
  if (!prof_stat)
    prof_stat = id_hash_allocate (PROF_MAX_DISTINCT / 2, sizeof (void *), sizeof (qr_time_t),
				  strhash, strhashcmp);
  if (prof_stat && prof_stat->ht_inserts)
    {
      prof_report ();
    }
  mutex_leave (prof_mtx);
  prof_on = (long) bif_long_arg (qst, args, 0, "profile_enable");
  n_args = BOX_ELEMENTS (args) - 1;
  prof_stat_table = (n_args == 1) ? (long) bif_long_arg (qst, args, 1, "profile_enable") : 0;

  if (prof_on)
    {
      client_connection_t * cli = ((QI*)qst)->qi_client;
      prof_start_time = get_msec_real_time ();
      time (&prof_start_time_st);
      cli->cli_run_clocks = 0;
      cli->cli_cl_start_ts = 0;
      da_clear (&cli->cli_activity);
      da_clear (&cli->cli_compile_activity);
    }
  if (!prof_on && ql_file)
    {
      mutex_enter (&ql_mtx);
      fd_close (tcpses_get_fd (ql_file->dks_session), c_query_log_file);
      PrpcSessionFree (ql_file);
      ql_file = NULL;
      mutex_leave (&ql_mtx);
    }
  return 0;
}

caddr_t
bif_profile_sample (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t text = bif_string_arg (qst, args, 0, "prof_sample");
  long t = (long) bif_long_arg (qst, args, 1, "prof_sample");
  long f = (long) bif_long_arg (qst, args, 2, "prof_sample");
  if (prof_on)
    prof_exec (NULL, text, t, f);
  return NULL;
}


caddr_t
bif_prof_proc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  QNCAST (QI, qi, qst);
  qi->qi_log_stats = 1;
  return NULL;
}


caddr_t
bif_msec_time (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return (box_num (get_msec_real_time ()));
}


caddr_t
bif_usec_time (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  timeout_t time_now;
  get_real_time (&time_now);
  return box_num ((int64)time_now.to_sec * 1000000 + time_now.to_usec);
}


caddr_t
dbg_print_itcs (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

/*
 *  Debugging output
 */

int
dbg_print_wpos_aux (FILE *out, wpos_t elt)
{
  if (0x7F000000 == (elt & 0xFF000000))
    {
      fprintf (out, "2G-%ld", (long)(0x80000000UL - ((unsigned) elt)));
      return 1;
    }
  if (0x80000000 == (elt & 0xFF000000))
    {
      fprintf (out, "2G+%ld", (long)(((long) elt) - 0x80000000L));
      return 1;
    }
  if (0xFF000000 == (elt & 0xFF000000))
    {
      fprintf (out, "4G-%ld", -((long)elt));
      return 1;
    }
  if (0x00000000 == (elt & 0xFF000000))
    {
      fprintf (out, "%ld", (long) elt);
      return 1;
    }
  return 0;
}


void
dbg_print_d_id_aux (FILE *out, d_id_t *d_id_buf_ptr)
{
  int ctr;
  for (ctr = 4; ctr < 32; ctr++)
  if (0 != d_id_buf_ptr->id[ctr])
    goto print_d_id_as_binary;
  if (D_INITIAL(d_id_buf_ptr))
    {
      fprintf (out, "init_d_id");
      return;
    }
  if (D_PRESET(d_id_buf_ptr))
    {
      fprintf (out, "preset_d_id");
      return;
    }
  if (D_NEXT(d_id_buf_ptr))
    {
      fprintf (out, "next_d_id");
      return;
    }
  if (0xFF == d_id_buf_ptr->id[0])
    goto print_d_id_as_binary;
  for (ctr = 0; ctr < 4; ctr++)
    fprintf (out, "%02x", (unsigned int)(d_id_buf_ptr->id[ctr]));
    return;
  print_d_id_as_binary:
  for (ctr = 0; ctr < 32; ctr++)
    fprintf (out, "%02x", (unsigned int)(d_id_buf_ptr->id[ctr]));
}

void
dbg_print_string_box (ccaddr_t object, FILE * out)
{
  const char *end = object + box_length (object) - 1;
  const char *tail;
  for (tail = object; tail < end; tail++)
    {
      switch (tail[0])
        {
	case '\'': fprintf (out, "\\\'"); break;
	case '\"': fprintf (out, "\\\""); break;
	case '\r': fprintf (out, "\\r"); break;
	case '\n': fprintf (out, "\\n"); break;
	case '\t': fprintf (out, "\\t"); break;
	case '\\': fprintf (out, "\\\\"); break;
	default:
          if ((unsigned char)(tail[0]) < ' ')
	    fprintf (out, "\\0%d%d", (tail[0] >> 3) & 7,  tail[0] & 7);
	  else
	    fputc (tail[0], out);
	}
    }
}

void
dbg_print_box_aux (caddr_t object, FILE * out, dk_hash_t *known)
{
  char temp[0x100];
  if (object == NULL)
    {
      fprintf (out, "0");
      return;
    }
  if (((ptrlong)object) == 0xaaaaaaaa)
    {
      fprintf (out, "!!!0xAAAAAAAA!!!");
      return;
    }
  if (((ptrlong)object) == 0xcccccccc)
    {
      fprintf (out, "!!!0xCCCCCCCC!!!");
      return;
    }
  if (((ptrlong)object) == 0xdeadbeef)
    {
      fprintf (out, "!!!0xDEADBEEF!!!");
      return;
    }
  if (!IS_BOX_POINTER (object))
    {
      fprintf (out, "%ld ", (long) (ptrlong) object);
      return;
    }
  if (gethash (object, known))
    {
      fprintf (out, "\n[PRINTED_ABOVE[%p]]\n", object);
    }
  else
    {
      dtp_t tag = box_tag (object);
/*      sethash (object, known, (void *)(1));*/
      switch (tag)
	{
	case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL:
	  {
	    long length = box_length (object) / sizeof (caddr_t);
	    long n;
	    fprintf (out, "(");
	    for (n = 0; n < length; n++)
	      {
		caddr_t elt = ((caddr_t *) object)[n];
		if IS_POINTER (elt)
		  dbg_print_box_aux (elt, out, known);
		else
		  fprintf (out, "%ld", (long) (ptrlong) elt);
		fprintf (out, " ");
	      }
	    fprintf (out, ")");
	    break;
	  }

	case DV_TEXT_SEARCH:
	  {
#if 1
	    fprintf (out, "[fts_query[...]] ");
#else
	    long length = box_length (object) / sizeof (caddr_t);
	    long n;
	    fprintf (out, "[fts_query[");
	    for (n = 0; n < length; n++)
	      {
		caddr_t elt = ((caddr_t *) object)[n];
		fprintf (out, " ");
		if ((length >= (n + (32/sizeof(char *)))) && (
		       ((31 + 5*(32/sizeof(char *))) == n) ||
		       ((27 + 4*(32/sizeof(char *))) == n) ||
		       ((27 + 3*(32/sizeof(char *))) == n) ||
		       ((27 + 2*(32/sizeof(char *))) == n) ||
		       ((19 + 1*(32/sizeof(char *))) == n) ||
		       (1 == n) ) )
		  {
		    dbg_print_d_id_aux (out, (unsigned char *)(((caddr_t *) object)+n));
		    continue;
		  }
		if ((length >= (31 + 6*(32/sizeof(char *)))) && (
		       ((23 + 2*(32/sizeof(char *))) == n) ) )
		  {
		    fprintf (out, "[query_instance[...]] ");
		    continue;
		  }
		if (dbg_print_wpos_aux (out, (ptrlong)(elt)))
		  continue;
		if (IS_POINTER (elt))
		  dbg_print_box_aux (elt, out, known);
		else
		  fprintf (out, "%ld", (long) elt);
	      }
	    fprintf (out, "]]");
#endif
	    break;
	  }

	case DV_XPATH_QUERY:
	  {
	    long length = box_length (object) / sizeof (caddr_t);
	    long n;
	    fprintf (out, "[xp_query[");
	    for (n = 0; n < length; n++)
	      {
		caddr_t elt = ((caddr_t *) object)[n];
		fprintf (out, " ");
		if (dbg_print_wpos_aux (out, (wpos_t)(ptrlong)(elt)))
		  continue;
		if (IS_POINTER (elt))
		  dbg_print_box_aux (elt, out, known);
		else
		  fprintf (out, "%ld", (long) (ptrlong) elt);
	      }
	    fprintf (out, "]]");
	    break;
	  }

	case DV_ARRAY_OF_LONG:
	  {
	    long length = box_length (object) / sizeof (ptrlong);
	    long n;
	    fprintf (out, "L(");
	    for (n = 0; n < length; n++)
	      {
		fprintf (out, "%ld ", ((ptrlong *) object)[n]);
	      }
	    fprintf (out, ")");
	    break;
	  }

	case DV_ARRAY_OF_DOUBLE:
	  {
	    long length = box_length (object) / sizeof (double);
	    long n;
	    fprintf (out, "#D(");
	    for (n = 0; n < length; n++)
	      {
		fprintf (out, "%f ", ((double *) object)[n]);
	      }
	    fprintf (out, ")");
	    break;
	  }

	case DV_ARRAY_OF_FLOAT:
	  {
	    long length = box_length (object) / sizeof (float);
	    long n;
	    fprintf (out, "#F(");
	    for (n = 0; n < length; n++)
	      {
		fprintf (out, "%f ", ((float *) object)[n]);
	      }
	    fprintf (out, ")");
	    break;
	  }

	case DV_LONG_INT:
	  fprintf (out, BOXINT_FMT"ld", unbox (object));
	  break;

	case DV_STRING:
	case DV_SYMBOL:
	case DV_C_STRING:
	  fprintf (out, "'");
	  dbg_print_string_box (object, out);
	  fprintf (out, "'");
	  break;
	case DV_UNAME:
	  fprintf (out, "UNAME'");
	  dbg_print_string_box (object, out);
	  fprintf (out, "'");
	  break;

	case DV_SINGLE_FLOAT:
	  fprintf (out, "%f", *(float *) object);
	  break;

	case DV_DOUBLE_FLOAT:
	  fprintf (out, "%f", *(double *) object);
	  break;

	case DV_DB_NULL:
	  fprintf (out, "<DB NULL>");
	  break;

	case DV_BIN:
	  fprintf (out, "<BINARY %d bytes>", (int) (box_length (object)));
	  break;

	case DV_NUMERIC:
	  numeric_to_string ((numeric_t) object, temp, sizeof (temp));
	  fprintf (out, "#N%s", temp);
	  break;
	case DV_DATETIME:
	  dbg_dt_to_string (object, temp, sizeof (temp));
	  fprintf (out, "%s", temp);
	  break;
	case DV_WIDE:
	case DV_LONG_WIDE:
	  box_wide_string_as_narrow (object, temp, sizeof(temp) - 1, NULL);
	  fprintf (out, "N\"%s\"", temp);
	  break;
#ifdef BIF_XML
	case DV_XML_ENTITY:
	  {
	     dk_session_t *ses = strses_allocate ();
	     caddr_t val;
	     ((xml_entity_t *)object)->_->xe_serialize ((xml_entity_t *)object, ses);
	     if (!STRSES_CAN_BE_STRING (ses))
	       val = box_dv_short_string ("<XML of enormous size>");
	     else
	       val = strses_string (ses);
	     strses_free (ses);
	     fprintf (out, "XML{\n%s\n}", val);
	     dk_free_box (val);
	     break;
	  }
#endif
	case DV_COMPOSITE:
	  {
	    db_buf_t dv = (db_buf_t) object;
	    uint32 len;
	    db_buf_t dv_end;
	    if (box_length (object) < 3)
	      {
		fprintf (out, "<co of 0 elements> ");
	    break;
	      }
	    len = dv[1];
	    dv_end = dv + len;
	    dv += 2;
	    fprintf (out, "<co ");
	    while (dv < dv_end)
	      {
		caddr_t box;
		int l2 ;
		DB_BUF_TLEN (l2, *dv, dv);
		box = box_deserialize_string ((caddr_t) dv, l2, 0);
		dbg_print_box_aux (box, out, known);
		fprintf (out, " ");
		dk_free_tree (box);
		dv += l2;
	      }
	    fprintf (out, "> ");
	    break;
	}
        case DV_OBJECT:
	    {
	      sql_class_t * udt = UDT_I_CLASS (object);
	      fprintf (out, "{\n\t[obj:%p %s]\n", object, udt->scl_name);
	      dbg_udt_print_object (object, out);
	      fprintf (out, "}\n");
	    }
	  break;

        case DV_REFERENCE:
	    {
	      caddr_t udi = udo_find_object_by_ref (object);
	      sql_class_t * udt = UDT_I_CLASS (udi);
	      fprintf (out, "{\n\tREF:[ref:%p obj:%p %s]\n", object, udi, udt->scl_name);
	      dbg_udt_print_object (udi, out);
	      fprintf (out, "}\n");
	    }
	  break;
        case DV_IRI_ID:
            {
              iri_id_t iid = unbox_iri_id (object);
	      if (iid >= MIN_64BIT_BNODE_IRI_ID)
	        fprintf (out, "#ib" IIDBOXINT_FMT, (boxint)(iid-MIN_64BIT_BNODE_IRI_ID));
              else
	        fprintf (out, "#i" IIDBOXINT_FMT, (boxint)(iid));
              break;
            }
        case DV_RDF:
            {
              rdf_box_t *rb = (rdf_box_t *)object;
	      fprintf (out, "rdf_box(");
              dbg_print_box_aux (rb->rb_box, out, known);
	      fprintf (out, ",%ld,%ld,%ld,%ld", (long)(rb->rb_type), (long)(rb->rb_lang), (long)(rb->rb_ro_id), (long)(rb->rb_is_complete));
              if (rb->rb_chksum_tail)
                {
                  rdf_bigbox_t *rbb = (rdf_bigbox_t *)rb;
	          fprintf (out, ",");
                  dbg_print_box_aux (rbb->rbb_chksum, out, known);
	          fprintf (out, ",%ld", (long)(rbb->rbb_box_dtp));
                }
	      fprintf (out, ")");
              break;
            }
	case DV_DICT_ITERATOR:
	    {
	      fprintf (out, "<dictionary_reference>");
	      break;
	    }
	case DV_GEO:
	    {
	      caddr_t xx = geo_wkt ((caddr_t)object);
	      fprintf (out, "%s", xx);
	      dk_free_box (xx);
	      break;
	    }
	default:
	  {
	    fprintf (out, "Wacky box tag = %d\n", (int) tag);
	  }
	}
    }
}

void
dbg_print_box (caddr_t object, FILE * out)
{
  dk_hash_t *known = hash_table_allocate (4096);
  dbg_print_box_aux (object, out, known);
  hash_table_free (known);
}


void
dbg_print_box_dbx (caddr_t object)
{
  dbg_print_box (object, stderr);
}

/* Code to produce a page dump follows.
   For now, it is not in the production code until all output goes
   into the error log - PmN */

void
printf_dv (db_buf_t dv, FILE * out)
{
  char temp[15];
  switch (*dv)
    {
    case DV_SHORT_INT:
      fprintf (out, "%d ", (int) dv[1]);
      break;
    case DV_LONG_INT:
      fprintf (out, "%ld ", (long) LONG_REF (dv + 1));
      break;

    case DV_SHORT_STRING:
      {
	int n;
	int len = dv[1];
	if (*dv != DV_SHORT_STRING)
	  fprintf (out, "<G> ");
	dv += 2;
	for (n = 0; n < len; n++)
	  {
	    dtp_t c = dv[n];
	    if (c < 32 || c > 127)
	      c = '*';
	    temp[n] = c;
	    if (n > 12)
	      break;
	  }
	temp[n] = 0;
	fprintf (out, "\"%s\" ", temp);
	break;
      }
    case DV_SINGLE_FLOAT:
      {
	float f;
	EXT_TO_FLOAT (&f, (dv + 1));
	fprintf (out, "%f ", f);
	break;
      }
    case DV_DOUBLE_FLOAT:
      {
	double f;
	EXT_TO_DOUBLE (&f, (dv + 1));
	fprintf (out, "%f ", f);
	break;
      }
    default:
      fprintf (out, "dtp %d", (int) *dv);
    }
}


void
col_comp_print (FILE * out, dbe_key_t * key, db_buf_t row, dbe_col_loc_t * cl)
{
  row_ver_t rv = IE_ROW_VERSION (row);
  key_ver_t kv = IE_KEY_VERSION (row);
  int off, len;
  if (rv & cl->cl_row_version_mask)
    {
      unsigned short ref = SHORT_REF (row + cl->cl_pos[rv]);
      fprintf (out, "[R%d:%d]", (uint32)ref & ROW_NO_MASK, (uint32) ref >> COL_OFFSET_SHIFT);
    }
  else if (!dtp_is_fixed (cl->cl_sqt.sqt_dtp))
    {
      short pos = cl->cl_pos[rv];
      if (CL_FIRST_VAR == pos)
	{
	  off = kv ? key->key_row_var_start[rv] : key->key_key_var_start[rv];
	  len = SHORT_REF (row + key->key_length_area[rv]);
	  len -= off;
	}
      else
	{
	  off = COL_VAR_LEN_MASK & SHORT_REF (row - pos);
	  len = SHORT_REF (row + 2 - pos) - off;
	}
      if (len & COL_VAR_SUFFIX)
	{
	  unsigned short ref = SHORT_REF_NA (row + off);
	  dtp_t extra = 15 == (ref >> COL_OFFSET_SHIFT) ? row[off + 2] : 0;
	  fprintf (out, "[P%d:%d]", (uint32)ROW_NO_MASK & ref, extra ? extra : (uint32)ref >> COL_OFFSET_SHIFT);
	}
    }
}


int max_dump_str = 30;
#define RMAX max_dump_str

void
col_ref_print (FILE * out, db_buf_t xx, short vl1)
{
  int i;
  int n_ces = SHORT_REF_NA (xx + CPP_N_CES);
  fprintf (out, "[C %d ces, start %d dps ",
	   n_ces,  (int) SHORT_REF_NA (xx + CPP_FIRST_CE));
  for (i = CPP_DP; i < vl1; i += sizeof (dp_addr_t))
    fprintf (out, " %d", LONG_REF_NA (xx + i));
  fprintf (out, "] ");
}


void
col_str_print (db_buf_t str)
{
  col_ref_print (stdout, str, box_length (str) - 1);
  printf ("\n");
}


void
row_map_fprint (FILE * out, buffer_desc_t * buf, db_buf_t row, dbe_key_t * key)
{
  unsigned short offset;
  db_buf_t xx, xx2;
  unsigned short vl1, vl2;
  int c;
  key_ver_t kv = IE_KEY_VERSION (row);
  row_ver_t rv = IE_ROW_VERSION (row);
  int32 n32;
  int64 n64;
  dbe_col_loc_t * cl;
  int inx = 0, len;
  len = row_length (row, key);
  if (KV_LEFT_DUMMY == kv)
    {
      fprintf (out, "<left dummy> --> %d \n", (int)LONG_REF (row + LD_LEAF));
      return;
    }
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      if ((!kv || key->key_is_col) && ++inx > key->key_n_significant)
	break;
      cl = key_find_cl (key, col->col_id);
      if (cl->cl_null_mask[rv] && row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
	{
	  fprintf (out, "NULL");
	  goto next;
	}
      if (dtp_is_fixed (cl->cl_sqt.sqt_dtp))
	{
	  ROW_FIXED_COL (buf, row, rv, (*cl), xx);
	}
      else
	{
	  ROW_STR_COL (key, buf, row, cl, xx, vl1, xx2, vl2, offset);
	}
      switch (cl->cl_sqt.sqt_dtp)
	{
	case DV_SHORT_INT:
	  fprintf (out, " %d", SHORT_REF (xx));
	  break;
	case DV_IRI_ID:
          {
            iri_id_t iid;
	    ROW_INT_COL (buf, row, rv, (*cl), (iri_id_t)(uint32)LONG_REF, iid);

            if (iid >= MIN_64BIT_BNODE_IRI_ID)
	      fprintf (out, " #ib" IIDBOXINT_FMT, (boxint)(iid-MIN_64BIT_BNODE_IRI_ID));
            else
	      fprintf (out, " #i" IIDBOXINT_FMT, (boxint)(iid));
	    col_comp_print (out, key, row, cl);
            break;
          }
	case DV_LONG_INT:
	  ROW_INT_COL (buf, row, rv, (*cl), LONG_REF, n32);
	  fprintf (out, " %d", n32);
	  col_comp_print (out, key, row, cl);
	  break;
	case DV_INT64:
	  ROW_INT_COL (buf, row, rv, (*cl), INT64_REF, n64);
	  fprintf (out, " " BOXINT_FMT, n64);
	  col_comp_print (out, key, row, cl);
	  break;
	case DV_IRI_ID_8:
          {
            iri_id_t iid;
	    ROW_INT_COL (buf, row, rv, (*cl), INT64_REF, iid);
            if (iid >= MIN_64BIT_BNODE_IRI_ID)
	      fprintf (out, " #ib" BOXINT_FMT, (boxint)(iid-MIN_64BIT_BNODE_IRI_ID));
            else
	      fprintf (out, " #i" BOXINT_FMT, (boxint)(iid));
	    col_comp_print (out, key, row, cl);
            break;
          }
	case DV_STRING:
	  fprintf (out, " \"");
	  for (c = 0; c < MIN (RMAX, vl1); c++)
	    fprintf (out, "%c", xx[c] + (c == vl1 - 1 ? offset : 0));
	  if (vl1 > RMAX) fprintf (out, "...");
	  for (c = 0; c < MIN (RMAX, vl2); c++)
	    fprintf (out, "%c", xx2[c]);
	  fprintf (out, "\"");
	  if (vl2 > RMAX) fprintf (out, "...");
	  col_comp_print (out, key, row, cl);
	  break;
	case DV_ANY:
	  fprintf (out, " x");
	  for (c = 0; c < MIN (RMAX, vl1); c++)
	    fprintf (out, "%02x", (unsigned)((unsigned char)(xx[c] + (c == vl1 - 1 ? offset : 0))));
	  if (c > RMAX) fprintf (out, "...");
	  for (c = 0; c < MIN (RMAX, vl2); c++)
	    fprintf (out, "%02x", (unsigned)((unsigned char)(xx2[c])));
	  if (c > RMAX) fprintf (out, "...");
	  col_comp_print (out, key, row, cl);
	  break;
	case DV_TIMESTAMP:
	case DV_DATETIME:
	case DV_DATE:
	case DV_TIME:
	  fprintf (out, " dt 0x");
	  for (c = 0; c < 10; c++)
	    fprintf (out, "%02x", (unsigned)((unsigned char)(xx[c])));
		  fprintf (out, " ");

	  break;
	default:
	  fprintf (out, "<xx>");
	  col_comp_print (out, key, row, cl);
	  break;
	case DV_BLOB:
	case DV_BLOB_WIDE:
	case DV_BLOB_BIN:
	  {
	    dtp_t b_dtp = xx[0];
	    if (IS_STRING_DTP (b_dtp))
	      fprintf (out, " <inline blob %d> ", (int)b_dtp);
	    else
	      fprintf (out, "<blob dp=%d> ", LONG_REF_NA (xx + BL_DP));
	  }
	case DV_SINGLE_FLOAT:
	  {
	    float f;
	    EXT_TO_FLOAT (&f, xx);
	    fprintf (out, " %f ", f);
	    break;
	  }
	case DV_DOUBLE_FLOAT:
	  {
	    double f;
	    EXT_TO_DOUBLE (&f, xx);
	    fprintf (out, " %g ", f);
	    break;
	  }
	}
      if (inx < key->key_n_significant - 1)
	fprintf (out, ",");
    next: ;
    }
  END_DO_SET();
  if (!kv)
    fprintf (out, "--> %d ", (int)LONG_REF (row + key->key_key_leaf[rv]));
  if (kv && key->key_is_col)
    {
      DO_CL (cl, key->key_row_var)
	{
	  db_buf_t xx, xx2;
	  unsigned short vl1, vl2, offset;
	  ROW_STR_COL (key, buf, row, cl, xx, vl1, xx2, vl2, offset);
	  col_ref_print (out, xx, vl1);
	}
      END_DO_CL;
    }
  fprintf (out, "\n");
}


void
row_map_print (buffer_desc_t * buf, db_buf_t row, dbe_key_t * key)
{
  row_map_fprint (stdout, buf, row, key);
}


void
dbg_page_map_f (buffer_desc_t * buf, FILE * out)
{
  int fl;
  char flag_str[10];
  db_buf_t page = buf->bd_buffer;


  long l;
  key_id_t page_key_id = LONG_REF (page + DP_KEY_ID);
  dbe_key_t * page_key = NULL;
  if (!wi_inst.wi_schema/* || !buf->bd_space*/)
    return;
  page_key = sch_id_to_key (wi_inst.wi_schema, page_key_id);
  fprintf (out, "Page %ld %s, child of %ld remap %ld   Key %s: \n",
	   (long) buf->bd_page,
	   " ",
	   (long) LONG_REF (buf->bd_buffer + DP_PARENT),
	   (long) buf->bd_physical_page,
	   page_key_id == KI_TEMP ? "temp key" : page_key ? page_key->key_name : "<no key>");
  if (DPF_BLOB == SHORT_REF (buf->bd_buffer + DP_FLAGS))
    {
      fprintf (out, "  Blob, extend = %ld, bytes = %ld\n",
	  (long) LONG_REF (buf->bd_buffer + DP_OVERFLOW),
	  (long) LONG_REF (buf->bd_buffer + DP_BLOB_LEN));
      return;
    }
  else if (DPF_BLOB_DIR == SHORT_REF (buf->bd_buffer + DP_FLAGS))
    {
      fprintf (out, "  BlobDir, extend = %ld, bytes = %ld\n",
	  (long) LONG_REF (buf->bd_buffer + DP_OVERFLOW),
	  (long) LONG_REF (buf->bd_buffer + DP_BLOB_LEN));
      return;
    }
  fflush (out);
  if (!page_key && buf->bd_tree)
    page_key = buf->bd_tree->it_key;
  if (!page_key || !buf->bd_content_map)
    return;
  DO_ROWS (buf, map_pos, row, NULL)
    {
      key_ver_t kv = IE_KEY_VERSION (row);
      dbe_key_t * row_key = NULL;
      if (buf->bd_content_map->pm_entries[map_pos] > PAGE_SZ)
	{
	  fprintf (out, "**** row offset %d  beyond page end.\n", (int)buf->bd_content_map->pm_entries[map_pos]);
	  continue;
	}
      if (!kv || KV_LEFT_DUMMY == kv )
	row_key = page_key;
      else
	row_key = page_key->key_versions[kv];
      if (KV_LEFT_DUMMY != kv && (!row_key || kv >= KEY_MAX_VERSIONS))
	{
	  fprintf (out, "**** Row with non-existent key kv %d\n", (int)kv);
	  continue;
	}
      l = row_length (row, row_key);
      flag_str[0] = 0;
      fl = 0x80 & IE_FLAGS (row);
      if (fl)
	snprintf (flag_str, sizeof (flag_str), "f: %x ", fl);
      fprintf (out, "    %d: %ldB  Key %ld: %s", map_pos, l,
	  (long) kv, flag_str);
      row_map_fprint (out, buf, row, row_key);
    }
  END_DO_ROWS;
}

void
dbg_hash_page_f (buffer_desc_t * buf, FILE * out)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  int rc;
  db_buf_t page = buf->bd_buffer;
  dbe_key_t * page_key = buf->bd_tree->it_key;
  fprintf (out, "Page %ld, next %ld : \n",
	   (long) buf->bd_page,
	   (long) LONG_REF (buf->bd_buffer + DP_OVERFLOW));
  if (DPF_BLOB == SHORT_REF (buf->bd_buffer + DP_FLAGS))
    {
      fprintf (out, "  Blob, extend = %ld, bytes = %ld\n",
	       (long) LONG_REF (buf->bd_buffer + DP_OVERFLOW),
	       (long) LONG_REF (buf->bd_buffer + DP_BLOB_LEN));
      return;
    }
  else if (DPF_BLOB_DIR == SHORT_REF (buf->bd_buffer + DP_FLAGS))
    {
      fprintf (out, "  BlobDir, extend = %ld, bytes = %ld\n",
	       (long) LONG_REF (buf->bd_buffer + DP_OVERFLOW),
	       (long) LONG_REF (buf->bd_buffer + DP_BLOB_LEN));
      return;
    }
  fflush (out);
  if (!page_key)
    return;
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, buf->bd_tree);
  itc->itc_map_pos = DP_DATA + HASH_HEAD_LEN;
  for (;;)
    {
      db_buf_t row;
      key_ver_t kv;
      if (ITC_AT_END == itc->itc_map_pos)
	return; /* the next in itc_next can move this to end.  Must not ref the kv, else can get by accidentr a 1 and think it's a row */
      row = page + itc->itc_map_pos;
      kv = IE_KEY_VERSION (row);
      if (kv!= 1)
	{
	  fprintf (out, "Bad kv %d at %d\n", (int)(dtp_t)row[itc->itc_map_pos], itc->itc_map_pos);
	  return;
	}
      itc->itc_row_data = page + itc->itc_map_pos;
      itc->itc_row_key = buf->bd_tree->it_key;
      row_map_fprint (out, buf, row, page_key);
      rc = itc_hash_next (itc, buf);
      if (DVC_INDEX_END == rc)
	break;
    }
  fprintf (out, "\n");
}

void
dbg_hash_page (buffer_desc_t * buf)
{
  dbg_hash_page_f (buf, stdout);
}



/*
 *  Called from bif page_dump ()
 */
void
dbg_page_map (buffer_desc_t * buf)
{
  dbg_page_map_f (buf, stderr);
}


void
dbg_page_map_log (buffer_desc_t * buf, char * fn, char * msg)
{
  FILE * f = fopen (fn, "a");
  fprintf (f, "%s\n", msg);
  dbg_page_map_f (buf, f);
  fflush (f);
  fclose (f);
}


/*
 *  Reports page inconsistency, probably just before repair
 *  Temporary fix
 */
void
dbg_page_structure_error (buffer_desc_t * buf, db_buf_t ptr)
{
  char trace[100];
  char *p;
  int inx;

  log_error ("** Page structure error on 0x%p", ptr);

  if (buf)
    {
      log_error ("   in buffer %p, logical %ld, physical %ld, offset %ld",
	  buf, buf->bd_page, buf->bd_physical_page,
	  (long) (ptr - buf->bd_buffer));

#ifndef NDEBUG
      dbg_page_map (buf);
#endif
    }
  else
    log_error ("  not inside any buffer");

  trace [0] = 0;
  for (inx = 0, p = trace; inx < 32; inx++, p += 3)
    {
       char buf [3];
       snprintf (buf, sizeof (buf), "%02x ", ptr[inx]);
       strcat_ck (trace, buf);
    }
  log_error ("   trace %s", trace);
}


void
print_registry()
{
  id_hash_iterator_t hit;
  char** name;
  char** place;

  for (id_hash_iterator (&hit,registry);
       hit_next (&hit, (char**)&name, (char**)&place);
       /* */)
    {
      printf ("registry entry: %s [%s]\n", name ? name[0] : "NULL",
	      place ? place[0] : "NULL");
    }
}

caddr_t
dbg_print_itcs (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  DO_SET (index_tree_t *, it, &wi_inst.wi_master->dbs_trees)
    {
      int inx;
      for (inx = 0; inx < IT_N_MAPS; inx++)
	{
	  it_map_t * itm = &it->it_maps[inx];
	  int n = 0;
	  it_cursor_t *cr;
	  if (!itm->itm_dp_to_buf.ht_count)
	    continue;
	  printf ("tree %p: \n", (void *)it);
	  DO_HT (void *, ignore, buffer_desc_t *, buf, &itm->itm_dp_to_buf)
	    {
	      printf (" \npage %ld:", (long) buf->bd_page);
	      for (cr = buf->bd_registered; cr; cr = cr->itc_next_on_page)
		{
		  n++;
		  if (n > 1000)
		    {
		      break;
		    }
		}
	      printf (" %d crsrs: ", n);
	      n = 0;
	      for (cr = buf->bd_registered; cr; cr = cr->itc_next_on_page)
		{
		  printf (" %p ", (void *)cr);
		  if (n > 10)
		    break;
		  n++;
		}
	    }
	  END_DO_HT;
	}
    }
  END_DO_SET();
  printf ("\n");
  return 0;
}


char *
srv_st_dbms_name ()
{
   return st_dbms_name;
}


char * srv_st_dbms_ver ()
{
   return st_dbms_ver;
}

/* server storage stats */

#define STRUCTURE_FAULT_ERR \
    sqlr_new_error ("42000", "SR465", "structure fault at page %ld", (long)buf->bd_page)


typedef struct ce_info_s
{
  int64	cei_bytes;
  int64	cei_values;
  int64	cei_ces;
} ce_info_t;

typedef struct col_info_s
{
  dp_addr_t	coi_pages;
  int64	coi_bytes;
  int64	coi_values;
  ce_info_t	coi_cei[16];
} col_info_t;

typedef struct key_info_s
{
  dbe_key_t * ki_key;
  int64     ki_rows;
  int64     ki_row_bytes;
  int64     ki_blob_pages;
  int64     ki_pages;
  int64     ki_last_dp;
  col_info_t *	ki_cols;
} key_info_t;

key_info_t *
key_ki (dbe_key_t * key, dk_hash_t * ht, dp_addr_t dp)
{
  key_info_t * ki = (key_info_t *) gethash ((void *) (ptrlong) key->key_id, ht);
  if (!ki)
    {
      ki = (key_info_t *) dk_alloc_box_zero (sizeof (key_info_t), DV_BIN);
      ki->ki_key = key;
      ki->ki_last_dp = dp;
      ki->ki_pages = 1;
      sethash ((void *) (ptrlong) key->key_id, ht, (void *) ki);
      if (key->key_is_col)
	{
	  ki->ki_cols = (col_info_t*)dk_alloc_box_zero (sizeof (col_info_t) * key->key_n_parts, DV_STRING);
	}
    }
  return ki;
}


void
srv_collect_col_page_stats (buffer_desc_t * buf, dk_hash_t *ht)
{
  int r, total_bytes = 0, total_values = 0;
  page_map_t * pm = buf->bd_content_map;
  db_buf_t ce;
  dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, LONG_REF (buf->bd_buffer + DP_KEY_ID));
  col_info_t * coi;

  key_info_t * ki;
  oid_t col_id = LONG_REF (buf->bd_buffer + DP_PARENT);
  int icol = -1, nth = 0;
  if (!key)
    return;
  ki = key_ki (key, ht, 0);  DO_CL (cl, key->key_row_var)
    {
      if (col_id == cl->cl_col_id)
	{
	  icol = nth;
	  break;
	}
      nth++;
    }
  END_DO_CL;
  if (-1 == icol)
    return;
  coi = &ki->ki_cols[icol];
  for (r = 0; r < pm->pm_count; r += 2)
    {
      ce_info_t * cei;
      int bytes, values, hl;
      dtp_t ce_type, ignd;
      ce = BUF_ROW (buf, r);
      ce_head_info (ce, &bytes, &values, &ce_type, &ignd, &hl);
      cei = &coi->coi_cei[ce_type];
      cei->cei_bytes += bytes;
      cei->cei_values += values;
      cei->cei_ces++;
      total_bytes += bytes;
      total_values += values;
    }
  coi->coi_pages++;
  coi->coi_bytes += total_bytes;
  coi->coi_values += total_values;
}


static void
srv_collect_inx_page_stats (it_cursor_t * it, buffer_desc_t * buf, dk_hash_t *ht)
{
  db_buf_t page;
  dbe_key_t * page_key, *key;
  dp_addr_t parent_dp;

  page = buf->bd_buffer;

  /* page consistence check */
  parent_dp = (dp_addr_t) LONG_REF (buf->bd_buffer + DP_PARENT);
  if (parent_dp && parent_dp >= buf->bd_storage->dbs_n_pages)
    STRUCTURE_FAULT_ERR;

  dbg_printf_1 (("doing page %ld\n", (long) buf->bd_page));
  page_key = sch_id_to_key (wi_inst.wi_schema, LONG_REF (buf->bd_buffer + DP_KEY_ID));
  DO_ROWS (buf, map_pos, row, NULL)
    {
      if (buf->bd_content_map->pm_entries[map_pos] > PAGE_SZ)
	{
	  STRUCTURE_FAULT_ERR;
	}
      else
	{
	  key_ver_t kv = IE_KEY_VERSION (row);
	  dbe_key_t * row_key = page_key->key_versions[kv];

	  if (kv == KV_LEFT_DUMMY || !kv)
	    goto get_next;
	  if (!row_key)
	    STRUCTURE_FAULT_ERR;
	  if (1)
	    {
	      long l = row_length (row, row_key);
	      key_info_t *ki;

	      if (buf->bd_content_map->pm_entries[map_pos]+l > PAGE_SZ)
		STRUCTURE_FAULT_ERR;

	      key = row_key;
#if 0
	      while (key && key->key_migrate_to)
		{
		  key = sch_id_to_key (wi_inst.wi_schema, key->key_migrate_to);
		}
	      if (!key)
		STRUCTURE_FAULT_ERR;
#endif

	      ki = key_ki (key, ht, buf->bd_page);
	      ki->ki_rows += 1;
	      ki->ki_row_bytes += l;
	      if (ki->ki_last_dp != buf->bd_page)
		{
		  ki->ki_pages ++;
		  ki->ki_last_dp = buf->bd_page;
		}

	      /* blobs stats */
	      it->itc_row_key = row_key;
	      it->itc_insert_key = row_key;
	      it->itc_row_data = row;
	      if (row_key && row_key->key_row_var)
		{
		  int inx;
		  for (inx = 0; row_key->key_row_var[inx].cl_col_id; inx++)
		    {
		      dbe_col_loc_t * cl = &row_key->key_row_var[inx];
		      dtp_t dtp = cl->cl_sqt.sqt_dtp;
		      if (IS_BLOB_DTP (dtp))
			{
			  int off, len;
			  if (ITC_NULL_CK (it, (*cl)))
			    continue;
			  KEY_PRESENT_VAR_COL (it->itc_row_key, it->itc_row_data, (*cl), off, len);
			  dtp = it->itc_row_data[off];
			  if (IS_BLOB_DTP (dtp))
			    {
			      int64 bl_byte_len = INT64_REF_NA (it->itc_row_data + off + BL_BYTE_LEN);
			      ki->ki_blob_pages += (bl_byte_len / PAGE_DATA_SZ);
			      if (bl_byte_len % PAGE_DATA_SZ)
				ki->ki_blob_pages += 1;
			    }
			}
		    }
		}

	    }
	}
    get_next: ;
    }
  END_DO_ROWS;
}


static caddr_t
srv_collect_inx_space_stats (caddr_t *err_ret, query_instance_t *qi)
{
  buffer_desc_t *buf, *free_set;
  volatile dp_addr_t page_no;
  it_cursor_t *it;
  dk_hash_t *ht = hash_table_allocate (101);
  caddr_t err = NULL;
  dk_set_t set = NULL;
  wi_database_t db;

  assertion_on_read_fail = 0;

  it = itc_create (NULL, bootstrap_cli->cli_trx);

  if (!srv_have_global_lock(THREAD_CURRENT_THREAD))
    IN_CPT (qi->qi_trx);
  buf = buffer_allocate (DPF_INDEX);
  DO_SET (dbe_storage_t *, storage, &wi_inst.wi_master_wd->wd_storage)
    {
      if (storage->dbs_slices)
	continue;

  ITC_FAIL (it)
    {
      buf->bd_is_write = 1;

      buf->bd_page = buf->bd_physical_page = 0;
      buf->bd_storage = storage;
      if (WI_ERROR == buf_disk_read (buf))
	{
	  err = srv_make_new_error ("42000", "SR466", "Read of config page failed");
	  goto cfg_err;
	}
      memcpy (&db, buf->bd_buffer, sizeof (wi_database_t));
      free_set = dbs_read_page_set (storage, db.db_free_set, DPF_FREE_SET);

      QR_RESET_CTX
	{
	  for (page_no = 2; page_no < storage->dbs_n_pages; page_no++)
	    {
	      dp_addr_t page;
	      int inx, bit, rc;
	      uint32 *array, alloc;
	      IN_DBS (storage);
	      rc = dbs_locate_page_bit (storage, &free_set, page_no, &array, &page, &inx, &bit, V_EXT_OFFSET_FREE_SET, 0);
	      LEAVE_DBS (storage);
	      /* it may happen that dbs_n_pages is out of sync from the free_set which we read from disk.
		 thus in this case we just stop reading */
	      if (!rc)
		break;
	      alloc = (array[inx] & (1 << bit));
	      if (0 != alloc &&
		  !gethash (DP_ADDR2VOID (page_no), storage->dbs_cpt_remap))
		{
		  buf->bd_page = buf->bd_physical_page = page_no;
		  buf->bd_storage = storage;
		    if (!setjmp_splice (&structure_fault_ctx))
		      {
		  if (WI_ERROR == buf_disk_read (buf))
		    {
			    goto next_page;
		      err = srv_make_new_error ("42000", "SR466", "Read of page %ld failed", (unsigned long) page_no);
		      break;
		    }
		  else
		    {
		      if (DPF_INDEX == SHORT_REF (buf->bd_buffer + DP_FLAGS))
			{
			  srv_collect_inx_page_stats (it, buf, ht);
			}
		      else if (DPF_COLUMN == SHORT_REF (buf->bd_buffer + DP_FLAGS))
			srv_collect_col_page_stats (buf, ht);
		    }
		    }
		}
	      next_page: ;
	    }
	}
      QR_RESET_CODE
	{
	  err = thr_get_error_code (THREAD_CURRENT_THREAD);
	}
      END_QR_RESET;
      cfg_err:;
    }
  ITC_FAILED
    {
      err = srv_make_new_error ("42000", "SR467", "Error collecting the stats");
    }
  END_FAIL (it);
      if (err)
	break;
    }
  END_DO_SET();
  buffer_free (buf);
  dbg_printf_1 (("after pages collection\n"));

  itc_free (it);

    {
      dk_hash_iterator_t hit;
      key_info_t *ki;
      void *k;

      dk_hash_iterator (&hit, ht);
      while (dk_hit_next (&hit, &k, (void **) &ki))
	{
	  if (err)
	    dk_free_box ((box_t) ki);
	  else
	    {
	      caddr_t *res_part = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 7, DV_ARRAY_OF_POINTER);
	      res_part[0] = box_num (ki->ki_key->key_id);
	      res_part[1] = box_num (ki->ki_rows);
	      res_part[2] = box_num (ki->ki_row_bytes);
	      res_part[3] = box_num (ki->ki_blob_pages);
	      res_part[4] = box_num (ki->ki_pages);
	      res_part[5] = box_num (0);
	      res_part[6] = (box_t) ki->ki_cols;
	      dk_set_push (&set, res_part);
	      dk_free_box ((caddr_t)ki);
	    }
	}
    }

  if (!srv_have_global_lock(THREAD_CURRENT_THREAD))
    LEAVE_CPT(qi->qi_trx);

  hash_table_free (ht);
  *err_ret = err;
  return list_to_array (set);
}


static caddr_t
bif_sys_index_space_usage (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;

  sec_check_dba (qi, "sys_index_space_usage");
  return srv_collect_inx_space_stats (err_ret, qi);
}


caddr_t
bif_col_info (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  col_info_t * coi = (col_info_t*)bif_string_arg (qst, args, 0, "__col_info");
  int nth = bif_long_arg (qst, args, 1, "__col_info");
  caddr_t name = bif_string_arg (qst, args, 2, "__col_info");
  int ce_type = bif_long_arg (qst, args, 3, "__col_info");
  int n_cols = box_length (coi) / sizeof (col_info_t);
  if (nth >= n_cols || ce_type > 15)
    return NULL;
  coi += nth;
  if (!stricmp (name, "n_pages"))
    return box_num (coi->coi_pages);
  if (!stricmp (name, "n_values"))
    return box_num (coi->coi_values);
  if (!stricmp (name, "n_bytes"))
    return box_num (coi->coi_bytes);
  if (!strcmp (name, "ce_ces"))
    return box_num (coi->coi_cei[ce_type].cei_ces);
  if (!strcmp (name, "ce_values"))
    return box_num (coi->coi_cei[ce_type].cei_values);
  if (!strcmp (name, "ce_bytes"))
    return box_num (coi->coi_cei[ce_type].cei_bytes);
  sqlr_new_error ("42000", "COL..", "Bad attribute %s for __col_info", name);
  return NULL;
}

#ifndef NDEBUG
typedef enum {
  _in_artm_fptr = 0,
  _in_pred,
  _in_compare,
  _ins_call,
  _ins_call_ind,
  _ins_subq,
  _ins_qnode,
  _ins_open,
  _ins_fetch,
  _ins_close,
  _ins_handler,
  _ins_handler_end,
  _ins_bret,
  _ins_vret,
  _ins_jump,
  _ins_breakpoint,
  _ins_compound_start,
  _ins_compound_end,
  _ins_other,
  _ins_artm,
  _ins_end,
} _ins_type;

const char *col_names [] = {
  "NAME",
  "LEN",
  "REAL_LEN",
  "H_ARTM_FPTR",
  "H_PRED",
  "H_COMPARE",
  "H_CALL",
  "H_CALL_IND",
  "H_SUBQ",
  "H_QNODE",
  "H_OPEN",
  "H_FETCH",
  "H_CLOSE",
  "H_HANDLER",
  "H_HANDLER_END",
  "H_BRET",
  "H_VRET",
  "H_JUMP",
  "H_BREAKPOINT",
  "H_COMPOUND_START",
  "H_COMPOUND_END",
  "H_OTHER",
  "H_ARTM",
  "CNT"
};

static int
real_cv_print_proc (query_t *qr, ptrlong hist[], ptrlong *gl, ptrlong *gcnt)
{
  int l = box_length (qr->qr_head_node->src_pre_code), inx, real_len, cnt = 0;
  int lhist[_ins_end];
  caddr_t tmp[23];

  memset (&lhist[0], 0, sizeof (lhist));
  real_len = 0;
  DO_INSTR (ins, 0, qr->qr_head_node->src_pre_code)
    {
      switch (ins->ins_type)
	{
	  case IN_ARTM_FPTR: 	lhist[_in_artm_fptr]++; real_len += sizeof (ins->_.artm_fptr); break;
	  case IN_PRED: 	lhist[_in_pred]++; real_len += sizeof (ins->_.pred); break;
	  case IN_COMPARE: 	lhist[_in_compare]++; real_len += sizeof (ins->_.pred); break;
	  case INS_CALL: 	lhist[_ins_call]++; real_len += sizeof (ins->_.call); break;
	  case INS_CALL_IND: 	lhist[_ins_call_ind]++; real_len += sizeof (ins->_.call); break;
	  case INS_SUBQ: 	lhist[_ins_subq]++; real_len += sizeof (ins->_.subq); break;
	  case INS_QNODE: 	lhist[_ins_qnode]++; real_len += sizeof (ins->_.qnode); break;
	  case INS_OPEN: 	lhist[_ins_open]++; real_len += sizeof (ins->_.open); break;
	  case INS_FETCH: 	lhist[_ins_fetch]++; real_len += sizeof (ins->_.fetch); break;
	  case INS_CLOSE: 	lhist[_ins_close]++; real_len += sizeof (ins->_.close); break;
	  case INS_HANDLER: 	lhist[_ins_handler]++; real_len += sizeof (ins->_.handler); break;
	  case INS_HANDLER_END:	lhist[_ins_handler_end]++; real_len += sizeof (ins->_.handler_end); break;
	  case IN_BRET:		lhist[_ins_bret]++; real_len += sizeof (ins->_.bret); break;
	  case IN_VRET:		lhist[_ins_vret]++; real_len += sizeof (ins->_.vret); break;
	  case IN_JUMP:		lhist[_ins_jump]++; real_len += sizeof (ins->_.label); break;
	  case INS_BREAKPOINT:	lhist[_ins_breakpoint]++; real_len += sizeof (ins->_.breakpoint); break;
	  case IN_ARTM_PLUS: 	lhist[_ins_artm]++; real_len += sizeof (ins->_.artm); break;
	  case IN_ARTM_MINUS: 	lhist[_ins_artm]++; real_len += sizeof (ins->_.artm); break;
	  case IN_ARTM_TIMES: 	lhist[_ins_artm]++; real_len += sizeof (ins->_.artm); break;
	  case IN_ARTM_DIV: 	lhist[_ins_artm]++; real_len += sizeof (ins->_.artm); break;
	  case IN_ARTM_IDENTITY: lhist[_ins_artm]++; real_len += sizeof (ins->_.artm); break;

	  case INS_COMPOUND_START: 	lhist[_ins_compound_start] ++; break;
	  case INS_COMPOUND_END: 	lhist[_ins_compound_end] ++; break;
	  default: lhist[_ins_other] ++; real_len += INS_LEN (ins); break;
	}
      cnt++;
    }
  END_DO_INSTR;
  bif_result_inside_bif (24,
      qr->qr_proc_name,
      tmp[0] = box_num (l),
      tmp[1] = box_num (real_len),
      tmp[2] = box_num (lhist[_in_artm_fptr]),
      tmp[3] = box_num (lhist[_in_pred]),
      tmp[4] = box_num (lhist[_in_compare]),
      tmp[5] = box_num (lhist[_ins_call]),
      tmp[6] = box_num (lhist[_ins_call_ind]),
      tmp[7] = box_num (lhist[_ins_subq]),
      tmp[8] = box_num (lhist[_ins_qnode]),
      tmp[9] = box_num (lhist[_ins_open]),
      tmp[10] = box_num (lhist[_ins_fetch]),
      tmp[11] = box_num (lhist[_ins_close]),
      tmp[12] = box_num (lhist[_ins_handler]),
      tmp[13] = box_num (lhist[_ins_handler_end]),
      tmp[14] = box_num (lhist[_ins_bret]),
      tmp[15] = box_num (lhist[_ins_vret]),
      tmp[16] = box_num (lhist[_ins_jump]),
      tmp[17] = box_num (lhist[_ins_breakpoint]),
      tmp[18] = box_num (lhist[_ins_compound_start]),
      tmp[19] = box_num (lhist[_ins_compound_end]),
      tmp[20] = box_num (lhist[_ins_other]),
      tmp[21] = box_num (lhist[_ins_artm]),
      tmp[22] = box_num (cnt));
  *gl += l;
  *gcnt += cnt;
  for (inx = 0; inx < _ins_end; inx++)
    hist[inx] += lhist[inx];
  for (inx = 0; inx < sizeof (tmp) / sizeof (caddr_t); inx ++)
    dk_free_tree (tmp[inx]);
  return real_len;
}


static void
real_cv_size_trset_start (caddr_t * qst)
{
  state_slot_t sample[24];
  state_slot_t **sbox;
  caddr_t err = NULL;
  int inx;

  sbox = (state_slot_t **) dk_alloc_box (22 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memset (&sample, 0, sizeof (sample));

  sbox[0] = &sample[0];
  sample[0].ssl_name = box_dv_uname_string (col_names[0]);
  sample[0].ssl_type = SSL_COLUMN;
  sample[0].ssl_dtp = DV_SHORT_STRING;
  sample[0].ssl_prec = MAX_NAME_LEN;

  for (inx = 1; inx < (sizeof (sample) / sizeof (state_slot_t)); inx++)
    {
      sample[inx].ssl_name = box_dv_uname_string (col_names[inx]);
      sample[inx].ssl_type = SSL_COLUMN;
      sample[inx].ssl_dtp = DV_LONG_INT;
      sbox[inx] = &sample[inx];
    }

  bif_result_names (qst, &err, sbox);

  dk_free_box ((caddr_t) sbox);
  if (err)
    sqlr_resignal (err);

  for (inx = 0; inx < sizeof (sample) / sizeof (state_slot_t); inx++)
    dk_free_box (sample[inx].ssl_name);
}

static caddr_t
bif_real_cv_size (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
   id_casemode_hash_iterator_t hit;
   query_t **pproc;
   ptrlong hist[_ins_end];
   ptrlong total_size = 0, total_real_len = 0, total_cnt = 0;
   dbe_schema_t *sc = isp_schema (NULL);
   caddr_t tmp[24];
   int inx;

   sec_check_dba ((query_instance_t *) qst, "_sys_real_cv_size");

   memset (&hist[0], 0, sizeof (hist));
   id_casemode_hash_iterator (&hit, sc->sc_name_to_object[sc_to_proc]);

   real_cv_size_trset_start (qst);
   while (id_casemode_hit_next (&hit, (char **) &pproc))
     {
       if (!pproc || !*pproc)
	 continue;
       total_real_len += real_cv_print_proc (*pproc, hist, &total_size, &total_cnt);
     }

   bif_result_inside_bif (24,
       tmp[0] = NEW_DB_NULL,
       tmp[1] = box_num (total_size),
       tmp[2] = box_num (total_real_len),
       tmp[3] = box_num (hist[_in_artm_fptr]),
       tmp[4] = box_num (hist[_in_pred]),
       tmp[5] = box_num (hist[_in_compare]),
       tmp[6] = box_num (hist[_ins_call]),
       tmp[7] = box_num (hist[_ins_call_ind]),
       tmp[8] = box_num (hist[_ins_subq]),
       tmp[9] = box_num (hist[_ins_qnode]),
       tmp[10] = box_num (hist[_ins_open]),
       tmp[11] = box_num (hist[_ins_fetch]),
       tmp[12] = box_num (hist[_ins_close]),
       tmp[13] = box_num (hist[_ins_handler]),
       tmp[14] = box_num (hist[_ins_handler_end]),
       tmp[15] = box_num (hist[_ins_bret]),
       tmp[16] = box_num (hist[_ins_vret]),
       tmp[17] = box_num (hist[_ins_jump]),
       tmp[18] = box_num (hist[_ins_breakpoint]),
       tmp[19] = box_num (hist[_ins_compound_start]),
       tmp[20] = box_num (hist[_ins_compound_end]),
       tmp[21] = box_num (hist[_ins_other]),
       tmp[22] = box_num (hist[_ins_artm]),
       tmp[23] = box_num (total_cnt));

   for (inx = 0; inx < sizeof (tmp) / sizeof (caddr_t); inx ++)
     dk_free_tree (tmp[inx]);
   return NULL;
}
#endif


int
key_stat_to_spec (caddr_t data, dbe_key_t * key, int nth,
search_spec_t *sp, it_cursor_t * itc, int * v_fill)
{
  int res = 0;
  dbe_column_t * left_col;
  left_col = (dbe_column_t *) dk_set_nth (key->key_parts, nth);
  sp->sp_cl = *key_find_cl (key, left_col->col_id);
  sp->sp_col = left_col;
  sp->sp_collation = sp->sp_col->col_sqt.sqt_collation;

  sp->sp_min_op  = CMP_EQ;
  sp->sp_max_op = CMP_NONE;
  res = sample_search_param_cast (itc, sp, data);
  sp->sp_min = itc->itc_search_par_fill - 1;
  return res;
}


caddr_t
bif_key_estimate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int n_parts = BOX_ELEMENTS (args) - 2;
  int64 res;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  search_spec_t specs[10];
  int v_fill = 0, inx;
  search_spec_t ** prev_sp;
  query_instance_t *qi = (query_instance_t *) qst;
  dbe_key_t * key = NULL;
  caddr_t tb_name = bif_string_arg (qst, args, 0, "sys_stat");
  caddr_t key_name = bif_string_arg (qst, args, 1, "sys_stat");
  dbe_table_t *tb = qi_name_to_table (qi, tb_name);
  if (!tb)
    {
      sqlr_new_error ("42S02", "SR243", "No table %s in key_estimate", tb_name);
    }
  if (2 == BOX_ELEMENTS (args))
    return box_num (dbe_key_count (tb->tb_primary_key));
  DO_SET (dbe_key_t *, key1, &tb->tb_keys)
    {
      if (0 == strcmp (key1->key_name, key_name))
	{
	  key = key1;
	  goto found;
	}
    }
  END_DO_SET();

  sqlr_new_error ("42S02", "SR243", "No key %s in key_estimate", key_name);
 found:
  dbe_key_count (key); /* max of the sample, must be defd */
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  itc_clear_stats (itc);
  memset (&specs,0,  sizeof (specs));
  prev_sp = &itc->itc_key_spec.ksp_spec_array;
  itc->itc_key_spec.ksp_key_cmp = NULL;
  for (inx = 0; inx < n_parts; inx++)
    {
      res = key_stat_to_spec (bif_arg (qst, args, inx + 2, "key_estimate"),key, inx, &specs[inx],
			       itc, &v_fill);
      if (KS_CAST_OK != res)
	{
	  itc_free (itc);
	  return box_num (KS_CAST_NULL == res ? 0 : -1);
	}
      *prev_sp = &specs[inx];
      prev_sp = &specs[inx].sp_next;
    }
  if (!key->key_is_elastic)
    itc_from_keep_params (itc, key, QI_NO_SLICE);
  res = itc_sample (itc);
  return box_num (res);
}


#define S_ADD(m) a1->m += a2->m
#define S_SUB(m) a1->m -= a2->m


void
da_add (db_activity_t * a1, db_activity_t * a2)
{
  S_ADD (da_random_rows);
  S_ADD (da_seq_rows);
  S_ADD (da_same_seg);
  S_ADD (da_same_page);
  S_ADD (da_same_parent);
  S_ADD (da_thread_time);
  S_ADD (da_thread_disk_wait);
  S_ADD (da_thread_cl_wait);
  S_ADD (da_thread_pg_wait);
  S_ADD (da_qp_thread);
  S_ADD (da_lock_waits);
  S_ADD (da_lock_wait_msec);
  S_ADD (da_disk_reads);
  S_ADD (da_spec_disk_reads);
  S_ADD (da_cl_messages);
  S_ADD (da_cl_bytes);
  S_ADD (da_trans_rows);
  a1->da_anytime_result |= a2->da_anytime_result;
  a1->da_trans_partial |= a2->da_trans_partial;
}


void
da_sub (db_activity_t * a1, db_activity_t * a2)
{
  S_SUB (da_random_rows);
  S_SUB (da_seq_rows);
  S_SUB (da_same_seg);
  S_SUB (da_same_page);
  S_SUB (da_same_parent);
  S_SUB (da_thread_time);
  S_SUB (da_thread_disk_wait);
  S_SUB (da_thread_cl_wait);
  S_SUB (da_thread_pg_wait);
  S_SUB (da_qp_thread);
  S_SUB (da_lock_waits);
  S_SUB (da_lock_wait_msec);
  S_SUB (da_disk_reads);
  S_SUB (da_spec_disk_reads);
  S_SUB (da_cl_messages);
  S_SUB (da_cl_bytes);
  a1->da_anytime_result |= a2->da_anytime_result;
}

void
da_copy (db_activity_t * to, db_activity_t * from)
{
  int64 * save = from->da_nodes;
  *to = *from;
  to->da_nodes = NULL;
  memzero (from, sizeof (db_activity_t));
  from->da_nodes = save;
}


void
da_clear (db_activity_t * da)
{
  int64 * nodes = da->da_nodes;
  memzero (da, sizeof (db_activity_t));
  da->da_nodes = nodes;
}


double
rep_num_scale (double n, char ** scale_ret, int is_base_2)
{
  double dec_scale[] = {1000, 1000000, 1000000000, 1000000000000, 0};
  double bin_scale[] = {1024, 1024*1024,  1024*1024*1024,   1024.0*1024*1024*1024, 0};
  double * scale = is_base_2 ? bin_scale : dec_scale;
  static char * empty = "";
  static char * letter[] = {"K", "M", "G", "T", ""};
  int inx;
  for (inx = 0; inx < 4; inx++)
    {
      if (n < scale[inx])
	break;
    }
  if (!inx)
    {
      *scale_ret = empty;
      return n;
    }
  *scale_ret = letter[inx - 1];
  return n / scale[inx - 1];
}


void
da_string (db_activity_t * da, char * out, int len)
{
  char *rans, *seqs, *rs, * bs, *ms, *same_segs, *same_pages, *same_pars, *specs, *qps;
  double ran = rep_num_scale (da->da_random_rows, &rans, 0);
  double seq = rep_num_scale (da->da_seq_rows, &seqs, 0);
  double same_seg = rep_num_scale (da->da_same_seg, &same_segs, 0);
  double same_page = rep_num_scale (da->da_same_page, &same_pages, 0);
  double same_par = rep_num_scale (da->da_same_parent, &same_pars, 0);
  double reads = rep_num_scale (da->da_disk_reads, &rs, 0);
  double spec_reads = rep_num_scale (da->da_spec_disk_reads, &specs, 0);
  double bytes = rep_num_scale (da->da_cl_bytes, &bs, 1);
  double msgs = rep_num_scale (da->da_cl_messages, &ms, 0);
  double qp = rep_num_scale (da->da_qp_thread, &qps, 0);
  snprintf (out, len, "%6.4g%s rnd %6.4g%s seq %6.4g%s same seg  %6.4g%s same pg %6.4g%s same par %6.4g%s disk %6.4g%s spec disk %6.4g%sB / %6.4g%s messages %6.4g%s fork",
	    ran, rans, seq, seqs,
	    same_seg, same_segs, same_page, same_pages, same_par, same_pars,
	    reads, rs, spec_reads, specs, bytes, bs, msgs, ms, qp, qps);
}


db_activity_t http_activity;

caddr_t
bif_db_activity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* no flag or 0 means text summary.  1 means array.  Or a 2 bit to flag  in order not to reset the counts */
  int flag = BOX_ELEMENTS (args) > 0 ? bif_long_arg (qst, args, 0, "db_activity") : 0;
  caddr_t acct = BOX_ELEMENTS (args) > 1 ? bif_string_arg (qst, args, 1, "db_activity") : "client";
  QNCAST (query_instance_t, qi, qst);
  db_activity_t * da =
    0 == strcmp (acct,  "http") ? &http_activity
    : &qi->qi_client->cli_activity;
  caddr_t res;
  if ((flag & 1))
    res = list (8, box_num (da->da_random_rows), box_num (da->da_seq_rows), box_num (da->da_lock_waits),
		box_num (da->da_lock_wait_msec), box_num (da->da_disk_reads), box_num (da->da_spec_disk_reads),
		box_num (da->da_cl_messages), box_num (da->da_cl_bytes));
  else
    {
      char txt[200];
      da_string (da, txt, sizeof (txt));
      res = box_dv_short_string (txt);
    }
  if (!(flag & 2))
    memset (da, 0, sizeof (db_activity_t));
  return res;
}


caddr_t
bif_key_seg_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int id = bif_long_arg (qst, args, 0, "key_seg_check");
  int inx;
  enable_pogs_check = 1;
  for (inx = 0; inx < sizeof (key_seg_check) / sizeof (int); inx++)
    {
      if (!key_seg_check[inx])
	{
	  key_seg_check[inx] = id;
	  return NULL;
	}
    }
  sqlr_new_error ("XXXXX", "COLCK", "too many keys being in key seg check");
  return NULL;
}

caddr_t
bif_lt_w_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int64 id = ((query_instance_t*)qst)->qi_trx->lt_w_id;
  if (!id) bing ();
  return box_num (id);
}

caddr_t
bif_lt_rc_w_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (((query_instance_t*)qst)->qi_trx->lt_rc_w_id);
}


void
bif_status_init (void)
{
#ifdef WIN32
  DWORD size = sizeof (st_os_user_name);
  if (!GetUserName (st_os_user_name, &size))
    strcpy_ck (st_os_user_name, "<unknown>");
#else
  struct passwd *pwd = getpwuid(geteuid());
  strncpy (st_os_user_name, pwd ? pwd->pw_name : "<unknown>", sizeof (st_os_user_name));
#endif
  bif_define ("status", bif_status);
  bif_define ("sys_stat", bif_sys_stat);
  bif_define ("__dbf_set", bif_dbf_set);
  bif_define_typed ("key_stat", bif_key_stat, &bt_integer);
  bif_define_typed ("key_estimate", bif_key_estimate, &bt_integer);
  bif_define_typed ("col_stat", bif_col_stat, &bt_integer);
  bif_define ("__col_info", bif_col_info);
  bif_define ("prof_enable", bif_profile_enable);
  bif_define ("prof_sample", bif_profile_sample);
  bif_define ("prof_proc", bif_prof_proc);
  bif_define_typed ("msec_time", bif_msec_time, &bt_integer);
  bif_define_typed ("usec_time", bif_usec_time, &bt_integer);
  bif_define_typed ("identify_self", bif_identify_self, &bt_any);
  ps_sem = semaphore_allocate (0);
  bif_define ("itcs", dbg_print_itcs);
  bif_define_typed ("sys_index_space_usage", bif_sys_index_space_usage, &bt_any);
  bif_define ("db_activity", bif_db_activity);
  bif_define ("ext_stat", bif_ext_stat);
  bif_define ("ext_em", bif_ext_em);
  bif_define ("key_seg_check", bif_key_seg_check);
  bif_define_typed ("lt_w_id", bif_lt_w_id, &bt_integer);
  bif_define_typed ("lt_rc_w_id", bif_lt_rc_w_id, &bt_integer);
#ifndef NDEBUG
  bif_define ("_sys_real_cv_size", bif_real_cv_size);
#endif
}


