/*
 *  $Id$
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

#include "sqlnode.h"
#include "monitor.h"


monitor_t statistics[DIMENSION_OF_STATISTICS];
uint32 mon_max_threads;
int mon_is_init;
int mon_enable = 0;
int mon_max_cpu_pct;

extern timeout_t time_now;
extern long disk_reads;
extern long read_block_usec;
extern long write_block_usec;
extern long read_cum_time;
extern long tc_no_thread_kill_idle;
extern long tc_no_thread_kill_vdb;
extern long tc_no_thread_kill_running;
extern long tc_read_wait;
extern long tc_write_wait;
extern long tc_cl_keep_alive_timeouts;
extern long tc_cl_deadlocks;
extern long lock_deadlocks;
extern long lock_waits;
extern long lock_wait_msec;
extern long tc_no_mem_for_longer_batch;
extern size_t mp_large_in_use;
extern long tc_part_hash_join;
extern long tc_slow_temp_insert;
extern long tc_slow_temp_lookup;
extern dk_cpu_set_t wi_affinity;
extern int thr_is_default_affinity;
extern unsigned char byte_logcount[256];
extern int32 enable_qp;

void mon_init() {
  if (thr_is_default_affinity) {
    int j, sum = 0;
    for (j = 0; j < sizeof(dk_cpu_set_t); j++)
      sum += byte_logcount[*(((unsigned char *)(&wi_affinity)) + j)];
    mon_max_threads = sum;
  }
  else
    mon_max_threads = enable_qp;
  mon_max_cpu_pct = 100 * mon_max_threads;
  mon_is_init = 1;
}

int mon_get_next(const monitor_t* previous, monitor_t *next) {
#ifdef HAVE_GETRUSAGE
  struct rusage r;
  next->mon_time_now = time_now.to_sec * 1000 + time_now.to_usec;
  if (getrusage(RUSAGE_SELF, &r) != 0)
    return 1;
  next->mon_cpu_time = r.ru_utime.tv_sec * 1000 + r.ru_utime.tv_usec - previous->mon_cpu_time;
  next->mon_cpu_pct = next->mon_cpu_time / (double)(next->mon_time_now - previous->mon_time_now) * 100;
  next->mon_pageflts = r.ru_majflt - previous->mon_pageflts;
  next->mon_disk_reads = disk_reads - previous->mon_disk_reads;
  next->mon_read_block_usec = read_block_usec - previous->mon_read_block_usec;
  next->mon_write_block_usec = write_block_usec - previous->mon_write_block_usec;
  next->mon_read_cum_time = read_cum_time - previous->mon_read_cum_time;
  // zajedno
  next->mon_tc_no_thread_kill_idle = tc_no_thread_kill_idle - previous->mon_tc_no_thread_kill_idle;
  next->mon_tc_no_thread_kill_vdb = tc_no_thread_kill_vdb - previous->mon_tc_no_thread_kill_vdb;
  next->mon_tc_no_thread_kill_running = tc_no_thread_kill_running - previous->mon_tc_no_thread_kill_running;
  next->mon_tc_read_wait = tc_read_wait - previous->mon_tc_read_wait;
  next->mon_tc_write_wait = tc_write_wait - previous->mon_tc_write_wait;
  next->mon_tc_cl_keep_alive_timeouts = tc_cl_keep_alive_timeouts - previous->mon_tc_cl_keep_alive_timeouts;
  next->mon_tc_cl_deadlocks = tc_cl_deadlocks - previous->mon_tc_cl_deadlocks;
  next->mon_lock_deadlocks = lock_deadlocks - previous->mon_lock_deadlocks;
  next->mon_lock_waits = lock_waits - previous->mon_lock_waits;
  next->mon_lock_wait_msec = lock_wait_msec - previous->mon_lock_wait_msec;
  next->mon_tc_no_mem_for_longer_batch = tc_no_mem_for_longer_batch - previous->mon_tc_no_mem_for_longer_batch;
  next->mon_mp_large_in_use = mp_large_in_use;
  next->mon_tc_part_hash_join = tc_part_hash_join - previous->mon_tc_part_hash_join;
  next->mon_tc_slow_temp_insert = tc_slow_temp_insert - previous->mon_tc_slow_temp_insert;
  next->mon_tc_slow_temp_lookup = tc_slow_temp_lookup - previous->mon_tc_slow_temp_lookup;
#endif
  return 0;
}

unsigned monitor_index = 0;

void
mon_update()
{
  unsigned monitor_index_previous;
  if (!mon_is_init || mon_enable)
    return;
  monitor_index_previous = monitor_index == 0 ? DIMENSION_OF_STATISTICS - 1 : monitor_index - 1;
  if (mon_get_next(statistics + monitor_index_previous, statistics + monitor_index) == 0) {
    monitor_index++;
    monitor_index %= DIMENSION_OF_STATISTICS;
  }
}


void
mon_check()
{
  if (!mon_is_init)
    return;
}
