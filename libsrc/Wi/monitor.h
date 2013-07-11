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

#ifndef _MONITOR_H
#define _MONITOR_H

#include <stdio.h>

typedef struct monitor_s {
  uint64 mon_time_now;
  long mon_cpu_time;
  double mon_cpu_pct;
  long mon_pageflts;
  long mon_disk_reads;
  long mon_read_block_usec;
  long mon_write_block_usec;
  long mon_read_cum_time;
  long mon_tc_no_thread_kill_idle;
  long mon_tc_no_thread_kill_vdb;
  long mon_tc_no_thread_kill_running;
  long mon_tc_read_wait;
  long mon_tc_write_wait;
  long mon_tc_cl_keep_alive_timeouts;
  long mon_tc_cl_deadlocks;
  long mon_lock_deadlocks;
  long mon_lock_waits;
  long mon_lock_wait_msec;
  long mon_tc_no_mem_for_longer_batch;
  size_t mon_mp_large_in_use;
  long mon_tc_part_hash_join;
  long mon_tc_slow_temp_insert;
  long mon_tc_slow_temp_lookup;
} monitor_t;


#define DIMENSION_OF_STATISTICS 60
#ifndef WIN32
#include <sys/time.h>
#include <sys/resource.h>
#endif
void mon_init();
int mon_get_next(const monitor_t* previous, monitor_t *next);
void mon_update();
void mon_check();



#endif
