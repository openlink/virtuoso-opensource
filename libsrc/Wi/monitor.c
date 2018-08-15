/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
#include "monitor.h"


#define DIMENSION_OF_STATISTICS 60
static monitor_t statistics[DIMENSION_OF_STATISTICS];
static long mon_log_time[PAGE_SZ]; /* 8k log checks */
uint32 mon_max_threads;
int mon_is_inited;
int32 mon_enable = 1;
int mon_max_cpu_pct;
double curr_cpu_pct = 0.0;

extern timeout_t time_now;
extern long disk_reads;
extern long read_block_usec;
extern long write_block_usec;
extern long read_cum_time;
extern long tc_no_thread_kill_idle;
extern long tc_no_thread_kill_vdb;
extern long tc_no_thread_kill_running;
extern long tws_accept_queued;
extern long tc_read_wait;
extern long tc_write_wait;
extern long tc_cl_keep_alive_timeouts;
extern long tc_cl_deadlocks;
extern long lock_deadlocks;
extern long lock_2r1w_deadlocks;
extern long lock_waits;
extern long lock_wait_msec;
extern long tc_no_mem_for_longer_batch;
extern size_t mp_large_in_use;
extern long tc_part_hash_join;
extern long tc_slow_temp_insert;
extern long tc_slow_temp_lookup;
extern unsigned char byte_logcount[256];
extern int32 enable_qp;
extern int64 mp_mmap_clocks;
static unsigned int monitor_index = 0;
static unsigned int current_inx; /* the last sample in stats */

#ifdef WIN32
static ULARGE_INTEGER lastCPU, lastSysCPU, lastUserCPU;
static int numProcessors;
static HANDLE me;
#endif

void
mon_init ()
{
  if (!mon_enable)
    return;
  mon_max_threads = enable_qp;
  mon_max_cpu_pct = 100 * mon_max_threads;
#ifdef WIN32
  {
    SYSTEM_INFO sysInfo;
    FILETIME ftime, fsys, fuser;
    GetSystemInfo (&sysInfo);
    numProcessors = sysInfo.dwNumberOfProcessors;
    GetSystemTimeAsFileTime (&ftime);
    memcpy (&lastCPU, &ftime, sizeof (FILETIME));
    me = GetCurrentProcess ();
    GetProcessTimes (me, &ftime, &ftime, &fsys, &fuser);
    memcpy (&lastSysCPU, &fsys, sizeof (FILETIME));
    memcpy (&lastUserCPU, &fuser, sizeof (FILETIME));
  }
#endif
  mon_is_inited = 1;
}

int
mon_get_next (int n_threads, int n_vdb_threads, int n_lw_threads, const monitor_t* prev, monitor_t *next)
{
  int thr_run = n_threads - n_vdb_threads - n_lw_threads;
  long now = get_msec_real_time ();
#ifdef HAVE_GETRUSAGE
  struct rusage ru;
  next->mon_time_now = now;
  next->mon_time_elapsed = now - prev->mon_time_now;
  if (getrusage (RUSAGE_SELF, &ru) != 0)
    return 1;
  next->mon_cpu_time = (ru.ru_utime.tv_sec * 1000 +  ru.ru_utime.tv_usec / 1000) + (ru.ru_stime.tv_sec * 1000 +  ru.ru_stime.tv_usec / 1000);
  curr_cpu_pct = next->mon_cpu_pct = (next->mon_cpu_time - prev->mon_cpu_time) / (double)(next->mon_time_now - prev->mon_time_now) * 100;
  next->mon_pageflts = ru.ru_majflt - prev->mon_pageflts;
#elif defined (WIN32)
  {
    FILETIME ftime, fsys, fuser;
    ULARGE_INTEGER now, sys, user;
    double percent;

    GetSystemTimeAsFileTime (&ftime);
    memcpy (&now, &ftime, sizeof (FILETIME));
    GetProcessTimes (me, &ftime, &ftime, &fsys, &fuser);
    memcpy (&sys, &fsys, sizeof (FILETIME));
    memcpy (&user, &fuser, sizeof (FILETIME));
    percent = (sys.QuadPart - lastSysCPU.QuadPart) + (user.QuadPart - lastUserCPU.QuadPart);
    percent /= (now.QuadPart - lastCPU.QuadPart);
    percent /= numProcessors;
    lastCPU = now;
    lastUserCPU = user;
    lastSysCPU = sys;
    curr_cpu_pct = next->mon_cpu_pct = percent * 100;
  }
#endif
  /* thread counts */
  next->mon_thr_run = thr_run;
  next->mon_thr = n_threads;
  next->mon_lw_thr = n_lw_threads;
  /* high cpu is when cpu% > 0.7 * min (runnable threads, max threads) */
  next->mon_high_cpu = ((uint32) next->mon_cpu_pct > (70.0 * MIN (thr_run, mon_max_threads)));
  next->mon_disk_reads = disk_reads;
  next->mon_read_block_usec = read_block_usec;
  next->mon_write_block_usec = write_block_usec;
  next->mon_read_cum_time = read_cum_time;
  next->mon_read_pct = (100.0 * (double) (next->mon_read_cum_time - prev->mon_read_cum_time)) / (double) next->mon_time_elapsed;

  next->mon_tc_no_thread_kill_idle = tc_no_thread_kill_idle;
  next->mon_tc_no_thread_kill_vdb = tc_no_thread_kill_vdb;
  next->mon_tc_no_thread_kill_running = tc_no_thread_kill_running;
  next->mon_tws_accept_queued = tws_accept_queued;

  next->mon_tc_read_wait = tc_read_wait;
  next->mon_tc_write_wait = tc_write_wait;
  next->mon_tc_cl_keep_alive_timeouts = tc_cl_keep_alive_timeouts;
  next->mon_tc_cl_deadlocks = tc_cl_deadlocks;
  next->mon_lock_deadlocks = lock_deadlocks;
  next->mon_lock_2r1w_deadlocks = lock_2r1w_deadlocks;
  next->mon_lock_waits = lock_waits;
  next->mon_lock_wait_msec = lock_wait_msec;

  /* memory */
  next->mon_mp_mmap_clocks = mp_mmap_clocks;
  next->mon_tc_no_mem_for_longer_batch = tc_no_mem_for_longer_batch;
  next->mon_mp_large_in_use = mp_large_in_use;
  next->mon_tc_part_hash_join = tc_part_hash_join;
  next->mon_tc_slow_temp_insert = tc_slow_temp_insert;
  next->mon_tc_slow_temp_lookup = tc_slow_temp_lookup;

  return 0;
}


void
mon_update (int n_threads, int n_vdb_threads, int n_lw_threads)
{
  unsigned int monitor_index_previous;
  if (!mon_is_inited || !mon_enable)
    return;
  monitor_index_previous = monitor_index == 0 ? DIMENSION_OF_STATISTICS - 1 : monitor_index - 1;
  if (mon_get_next (n_threads, n_vdb_threads, n_lw_threads, statistics + monitor_index_previous, statistics + monitor_index) == 0)
    {
      current_inx = monitor_index;
      monitor_index++;
      monitor_index %= DIMENSION_OF_STATISTICS;
    }
}

#define CLK_SCALE 2000000LL /* how many rtdsc clocks are 1msec */
#define LOG_INTERVAL_MSEC 120000L
#define MON_LOG "* Monitor: "
#define N_SAMPLES_CK 10
/* #define MON_DEBUG 1 */

#define MON_CK(name, cond, ck) \
static int \
mon_##name##_ck () \
{ \
  monitor_t * c, *p; \
  int i, current; \
  current = current_inx; \
  for (i = 0; i < N_SAMPLES_CK; i++) \
    { \
      c = &(statistics[current]); \
      current = (0 == current ? DIMENSION_OF_STATISTICS - 1 : current - 1); \
      p = &(statistics[current]); \
      if (ck) \
	return 0; \
      if (!cond) \
	return 0; \
    } \
  return 1; \
}

#define MON_LOG_WARNING(log) \
    do { \
      long last_ck = mon_log_time[i]; \
      if (!last_ck || ((now - last_ck) > LOG_INTERVAL_MSEC)) { \
      log_warning (log); \
      mon_log_time[i] = now; \
      } \
    } while (0)

#define CK(cond) if ((++i >= 0) && (cond))

MON_CK(read, (c->mon_read_pct > (2.0 * c->mon_cpu_pct)), (c->mon_cpu_pct <= 0))
MON_CK(locks, (c->mon_lw_thr > (0.7 * c->mon_thr)), (c->mon_thr <= 0))
MON_CK(thr_run, (c->mon_thr_run > (3 * mon_max_threads) && c->mon_high_cpu), 0)
MON_CK(tws, (c->mon_tws_accept_queued > p->mon_tws_accept_queued), 0)
MON_CK(thr, (c->mon_thr_run > mon_max_threads && c->mon_cpu_pct < 70.0), 0)
MON_CK(no_thr_idle, (c->mon_tc_no_thread_kill_idle > p->mon_tc_no_thread_kill_idle), 0)
MON_CK(no_thr_vdb, (c->mon_tc_no_thread_kill_vdb > p->mon_tc_no_thread_kill_vdb), 0)
MON_CK(no_thr_running, (c->mon_tc_no_thread_kill_running > p->mon_tc_no_thread_kill_running), 0)
MON_CK(no_part_hj, (c->mon_tc_part_hash_join > p->mon_tc_part_hash_join), 0)
MON_CK(no_qmem, (c->mon_tc_no_mem_for_longer_batch > p->mon_tc_no_mem_for_longer_batch), 0)

#define DELTA(m) (c->m - p->m)

void
mon_check ()
{
  monitor_t *c, *p;
  int prev_inx, i = 0;
  long now = get_msec_real_time ();
  if (!mon_is_inited)
    return;
  prev_inx = 0 == current_inx ? DIMENSION_OF_STATISTICS - 1 : current_inx - 1;
  c = &(statistics[current_inx]);
  p = &(statistics[prev_inx]);
#if defined(MON_DEBUG)
  fprintf (stderr, "thr# %d cpu: %.02f%% read: %.02f%%\n", c->mon_thr_run, c->mon_cpu_pct, c->mon_read_pct);
#endif
  /* disk */
  CK (main_bufs < DELTA (mon_disk_reads) && !c->mon_high_cpu)
    MON_LOG_WARNING (MON_LOG "High disk read (1)");
  CK (mon_read_ck ())
    MON_LOG_WARNING (MON_LOG "High disk read (2)");

  /* locks */
  CK (mon_locks_ck ())
    MON_LOG_WARNING (MON_LOG "Many lock waits");
  CK ((DELTA (mon_lock_deadlocks) + DELTA (mon_tc_cl_deadlocks)) > (0.1 * DELTA (mon_lock_waits)))
    MON_LOG_WARNING (MON_LOG "Should read for update because lock escalation from shared to exclusive fails frequently (1)");
  CK (DELTA (mon_lock_2r1w_deadlocks) > (0.1 * DELTA (mon_lock_deadlocks)))
    MON_LOG_WARNING (MON_LOG "Should read for update because lock escalation from shared to exclusive fails frequently (2)");
  CK (((double) DELTA (mon_lock_wait_msec) / (DELTA (mon_lock_waits) + 1)) > 1)
    MON_LOG_WARNING (MON_LOG "Locks are held for a long time");

  /* threads */
  CK (mon_tws_ck ())
    MON_LOG_WARNING (MON_LOG "No Web Server threads avalable, ServerThreads in [HTTP Server] may have to be increased");
  CK (mon_thr_run_ck ())
    MON_LOG_WARNING (MON_LOG "System is under high load. Adding cluster nodes or using more replicated copies may needed");
  CK (mon_thr_ck ())
    MON_LOG_WARNING (MON_LOG "CPU%% is low while there are large numbers of runnable threads");
  CK (mon_no_thr_idle_ck () || mon_no_thr_vdb_ck () || mon_no_thr_running_ck ())
    MON_LOG_WARNING (MON_LOG "There are too few client threads configured");

  /* memory */
  CK (((mp_mmap_clocks / CLK_SCALE) * 1.1) > now)
    MON_LOG_WARNING (MON_LOG "The mp_mmap_clocks over 10%% of real time");
  CK (mon_no_part_hj_ck ())
    MON_LOG_WARNING (MON_LOG "Low hash join space, try to increase HashJoinSpace");
  CK (mon_no_qmem_ck ())
    MON_LOG_WARNING (MON_LOG "Low query memory limit, try to increase MaxQueryMem");
}
