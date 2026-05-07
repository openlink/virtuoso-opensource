/*
 *  $Id$
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

#ifndef _MONITOR_H
#define _MONITOR_H

#include <stdio.h>

typedef struct monitor_s {
  uint64 mon_time_now; /* sample time, msecs */
  uint64 mon_time_elapsed; /* elapsed time, msecs */
  long mon_cpu_time;   /* rusage cpu time */
  double mon_cpu_pct;  /* cpu % */
  char mon_high_cpu;   /* high cpu flag */
  long mon_pageflts;
  long mon_disk_reads;
  int mon_thr_run;
  int mon_thr;
  int mon_lw_thr;
  int64 mon_read_block_usec;
  int64 mon_write_block_usec;
  long mon_read_cum_time;
  double mon_read_pct;
  long mon_tc_no_thread_kill_idle;
  long mon_tc_no_thread_kill_vdb;
  long mon_tc_no_thread_kill_running;
  long mon_tws_accept_queued;
  long mon_tc_read_wait;
  long mon_tc_write_wait;
  long mon_tc_cl_keep_alive_timeouts;
  long mon_tc_cl_deadlocks;
  long mon_lock_deadlocks;
  long mon_lock_2r1w_deadlocks;
  long mon_lock_waits;
  long mon_lock_wait_msec;
  long mon_tc_no_mem_for_longer_batch;
  size_t mon_mp_large_in_use;
  int64 mon_mp_mmap_clocks;
  long mon_tc_part_hash_join;
  long mon_tc_slow_temp_insert;
  long mon_tc_slow_temp_lookup;
} monitor_t;

typedef struct fs_monitor_s {
  unsigned long fm_sid;
  caddr_t fm_fs;
  uint64 fm_total;
  uint64 fm_free;
  double fm_free_pct;
} fs_monitor_t;

#define MAX_ERROR_EVENTS 1024*1024*10

#define EES_DISK  1
#define EES_PAGE  2
#define EES_BLOB  3
#define EES_LOCKS 4
#define EES_CPT 5

typedef struct error_event_s
{
  uint16 ee_sid;		/* sub-system id */
  uint64 ee_eid;		/* event id code */
  uint64 ee_count;
} error_event_t;

extern dk_hash_t *error_events_ht;
extern dk_hash_t *mon_fs;

#ifndef WIN32
#include <sys/time.h>
#include <sys/resource.h>
#endif
extern int process_is_swapping;
void mon_init (void);
int mon_get_next (int n_threads, int n_vdb_threads, int n_lw_threads, const monitor_t* previous, monitor_t *next);
void mon_update (int n_threads, int n_vdb_threads, int n_lw_threads);
void mon_check (void);
char * mon_get_size_units (char * buf, int len, uint64 size);
int mon_log_error_event (uint16 sid, uint64 eid, char *error, int max, int critical);

#endif
