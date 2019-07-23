/*
 *  gate.c
 *
 *  $Id$
 *
 *  Hyperspace and gate.
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

#define BUF_SEEMS_LEAF(buf, map) \
  ((map->pm_count < 2 || (KV_LEAF_PTR != IE_KEY_VERSION (buf->bd_buffer + map->pm_entries[1])) ) && DPF_INDEX == SHORT_REF (buf->bd_buffer + DP_FLAGS))



long in_while_read;
long second_reads;
int is_read_pending;
int checkpoint_while_read = 0;
unsigned int bp_hit_ctr;




int
itc_async_read_1 (it_cursor_t * itc, dp_addr_t dp, dp_addr_t phys_dp,
		  buffer_desc_t * buf, buffer_desc_t * decoy)
{
#if 0
#error Not supposed to be on with 5.0
  /* if the iq for the dp to read is busy, put the read in the iq instead of doing it here.
   * Called outside map, returns 1 inside map if the read was scheduled, otherwise returns 0 outside map. */
  int n;
  io_queue_t * iq = db_io_queue (ITC_STORAGE (itc), phys_dp);
  buffer_desc_t * queued;
  if (!iq || !iq_is_on ())
    return 0;
  queued = iq->iq_first;
  for (n = 0; n < 10; n++)
    {
      if (!queued)
	return 0;
      queued = queued->bd_iq_next;
    }
  /* items in the queue.  Add to the queue. */
  buf->bd_being_read = 1;
  ITC_IN_MAP (itc);
  buf->bd_page = 0;
  isp_set_buffer (itc->itc_space, dp, phys_dp, buf);
  buf->bd_write_waiting = NULL;
  itc->itc_n_reads++;
  ITC_MARK_READ (itc);
  buf->bd_waiting_read = decoy->bd_waiting_read;
  buf->bd_readers = 0;
  ITC_LEAVE_MAP (itc);
  iq_schedule (&buf, 1);
  ITC_IN_MAP (itc);
  return 1;
#else
  return 0;
#endif
}



#ifdef ADAPTIVE_LAND

void
itc_adaptive_read_inc (it_cursor_t * itc, buffer_desc_t * dest_buf)
{
  page_map_t * map = dest_buf->bd_content_map;
  if (PA_READ == itc->itc_dive_mode && !dest_buf->bd_readers && map && BUF_SEEMS_LEAF (dest_buf, map))
    {
      BD_SET_IS_WRITE (dest_buf, 1);
      itc->itc_dive_mode = PA_WRITE;
    }
  else
    dest_buf->bd_readers++;
}

#define ADAPTIVE_READ_INC(itc, dest_buf) \
  itc_adaptive_read_inc (itc, dest_buf)

#ifdef PAGE_DEBUG
#define AL_WAIT_SET_WRITER(buf) \
  { \
    if ((buf) && (buf)->bd_is_write) \
      (buf)->bd_writer = THREAD_CURRENT_THREAD; \
    BUF_DBG_ENTER (buf); \
  }
#else
#define AL_WAIT_SET_WRITER(buf)
#endif
#else

#define ADAPTIVE_READ_INC(itc, dest_buf) \
  dest_buf->bd_readers++

#define AL_WAIT_SET_WRITER(buf)

#endif

buffer_desc_t * bounds_check_buf;


#define ITC_ACT(itc) itc_activity (itc)


db_activity_t misc_activity;

db_activity_t *
itc_activity (it_cursor_t * itc)
{
  client_connection_t * cli;
  if (itc->itc_out_state)
    return &((QI*)itc->itc_out_state)->qi_client->cli_activity;
  else if ((cli = sqlc_client ()))
    return &cli->cli_activity;
  else
    return &misc_activity;
}


dp_addr_t pwa_trap_dp;

int
DBGP_NAME (page_wait_access) (DBGP_PARAMS it_cursor_t * itc, dp_addr_t dp,  buffer_desc_t * buf_from,
    buffer_desc_t ** buf_ret, int mode, int max_change)
{
  uint64 start_ts;
  buffer_desc_t decoy;
  buffer_desc_t *buf;
  dp_addr_t phys_dp;
#ifdef PAGE_DEBUG
  if (dp == pwa_trap_dp) bing ();
#endif
  itc->itc_to_reset = RWG_NO_WAIT;
  itc->itc_max_transit_change = max_change;
  itc->itc_must_kill_trx = 0;
  if (!dp)
    GPF_T1 ("Zero DP in page_fault_map_sem");

  if (buf_from)
    {
      ITC_IN_TRANSIT (itc, dp, buf_from->bd_page);
    }
  else
    ASSERT_IN_MAP (itc->itc_tree, dp);

  buf = IT_DP_TO_BUF (itc->itc_tree, dp);
  if (!buf)
    {
      ra_req_t * ra = NULL;
      IT_DP_REMAP (itc->itc_tree, dp, phys_dp);
#ifdef MTX_DEBUG
      if (!itc->itc_is_col)
	{
      em_check_dp (itc->itc_tree->it_extent_map, phys_dp);
      if (phys_dp != dp)
	em_check_dp (itc->itc_tree->it_extent_map, dp);
	}
#endif
      if ((DP_DELETED == phys_dp || dbs_may_be_free (itc->itc_tree->it_storage, phys_dp))
	  && !strchr (wi_inst.wi_open_mode, 'a'))
	{
	  log_error ("Reference to page with free remap dp = %ld, remap = %ld",
		     (long) phys_dp, (long) dp);
	  if (0 && DBS_PAGE_IN_RANGE (itc->itc_tree->it_storage, phys_dp))
	    dbs_page_allocated (itc->itc_tree->it_storage, phys_dp);
	  else
	    {
	      *buf_ret = PF_OF_DELETED;
	      itc->itc_must_kill_trx = 1;
	      itc->itc_to_reset = RWG_WAIT_ANY;
	      ITC_LEAVE_MAPS (itc);
	      return RWG_WAIT_ANY;
	    }
	}
      if (itc->itc_read_hook && itc->itc_read_hook (itc, buf_from, dp))
	{
	  /* read ahead is not guaranteed to get a buffer for all the reqd pages, including the page for which page wait acc was called.  So since this one page must in any case be had, turn off the hook for the recursive call so read is forced regardless of the hook pretending to get a buffer. */
	  int rc;
	  read_hook_t rh = itc->itc_read_hook;
	  itc->itc_read_hook = NULL;
	  rc =  page_wait_access (itc, dp, buf_from, buf_ret, mode, max_change);
	  itc->itc_read_hook = rh;
	  return rc;
	}
      memset (&decoy, 0, sizeof (buffer_desc_t));
      decoy.bd_being_read = 1;
      decoy.bd_page = dp;
      decoy.bd_tree = itc->itc_tree;
      if (PA_READ == mode)
	decoy.bd_readers = 1;
      else
	BD_SET_IS_WRITE (&decoy, 1);
      sethash (DP_ADDR2VOID (dp), &IT_DP_MAP (itc->itc_tree, dp)->itm_dp_to_buf, (void*)&decoy);
      ITC_LEAVE_MAPS (itc);
      buf = bp_get_buffer (NULL, BP_BUF_REQUIRED);
      is_read_pending++;
      buf->bd_being_read = 1;
      buf->bd_page = dp;
      buf->bd_storage = itc->itc_tree->it_storage;
      buf->bd_physical_page = phys_dp;
      BD_SET_IS_WRITE (buf, 0);
      buf->bd_write_waiting = NULL;
      if (buf_from && !itc->itc_landed)
	ra = itc_read_aside (itc, buf_from, dp);
      itc->itc_n_reads++;
      ITC_MARK_READ (itc);
      buf->bd_tree = itc->itc_tree;
      start_ts = rdtsc ();
      BUF_PW (buf);
      buf_disk_read (buf);
      ITC_ACT (itc)->da_thread_disk_wait += rdtsc () - start_ts;
      is_read_pending--;
      if (ra)
	itc_read_ahead_blob (itc, ra, RAB_SPECULATIVE);

      if (buf_from)
	{
	  ITC_IN_TRANSIT (itc, dp, buf_from->bd_page)
	    }
	  else
	    ITC_IN_KNOWN_MAP (itc, dp);
      sethash (DP_ADDR2VOID (dp), &IT_DP_MAP (itc->itc_tree, dp)->itm_dp_to_buf, (void*) buf);
      buf->bd_pl = (page_lock_t *) gethash (DP_ADDR2VOID (dp), &IT_DP_MAP (itc->itc_tree, dp)->itm_locks);
      itc->itc_pl = buf->bd_pl;
      DBG_PT_READ (buf, itc->itc_ltrx);
      buf->bd_being_read = 0;
      buf->bd_readers = decoy.bd_readers;
      BD_SET_IS_WRITE (buf, decoy.bd_is_write);
      buf->bd_read_waiting = decoy.bd_read_waiting;
      buf->bd_write_waiting = decoy.bd_write_waiting;
      /* this thread has read the buffer and is first in.  It will now let others in if this is read access and reads are waiting.  Otherwise what waits gets released when the itc leaves the page */
      /* There is no change.  The only one in is this one and it did only the read */
      if (buf_from)
	page_leave_inner (buf_from);
      page_mark_change (buf, RWG_WAIT_DISK);
      if (PA_READ == mode)
	page_release_read (buf);

      ITC_LEAVE_MAPS (itc);
      /* complete transit.  This counts as no change since itc was all the time in source and dest was acquired without possibility of interference */
      BUF_BOUNDS_CHECK (buf);
      buf_ext_check (buf);
      *buf_ret = buf;
      BUF_DBG_ENTER (buf);
      return itc->itc_to_reset;
    }
  if (buf->bd_being_read)
    {
      second_reads++;
      if (PA_READ == mode  && !itc->itc_landed && !buf->bd_is_write && !buf->bd_write_waiting)
	{
	  /* cheat here.  No registration needed because a read-read wait is safe */
	  page_read_queue_add (buf, itc);
	  if (buf_from)
	    page_leave_inner (buf_from);
	  start_ts = rdtsc ();
	  ITC_SEM_WAIT (itc);
	  *buf_ret = itc->itc_buf_entered; /* since this was a read-read, the  itc is now in one the buffer, out of map, since the thread which did the read put it there */
	  ITC_ACT (itc)->da_thread_disk_wait += rdtsc () - start_ts;
	  AL_WAIT_SET_WRITER (*buf_ret);
	  return itc->itc_to_reset;
	}
      if (itc->itc_landed && buf_from
	  && RWG_WAIT_NO_ENTRY_IF_WAIT != max_change)
	{
	  if (itc->itc_desc_order)
	    itc_skip_entry (itc, buf_from);
	  itc_register_safe (itc, buf_from);
	}
      itc->itc_to_reset = RWG_WAIT_NO_CHANGE;
      if (PA_READ == mode)
	page_read_queue_add (buf, itc);
      else
	page_write_queue_add (buf, itc);
      if (buf_from && RWG_WAIT_NO_ENTRY_IF_WAIT != max_change)
	page_leave_inner (buf_from);
      start_ts = rdtsc ();
      ITC_SEM_WAIT (itc);
      ITC_ACT(itc)->da_thread_disk_wait += rdtsc () - start_ts;
      *buf_ret = itc->itc_buf_entered;
      /*  transit complete. The caller for landed transit must check if unregister is needed.  If this was for no entry, as in up trans wait, then the itc will still be on the source. */
      AL_WAIT_SET_WRITER (*buf_ret);
      return itc->itc_to_reset;
    }
  /* there is a buffer.  See if can transit */
  if (PA_READ == mode)
    {
      if (!buf->bd_is_write
	  && !buf->bd_write_waiting)
	{
	  buf->bd_readers++;
	  if (buf_from)
	    page_leave_inner (buf_from);
	  itc->itc_pl = buf->bd_pl;
	  ITC_LEAVE_MAPS (itc);
	  BUF_BOUNDS_CHECK (buf);
	  *buf_ret = buf;
	  BUF_TOUCH (buf);
	  BUF_DBG_ENTER (buf);
	  return  itc->itc_to_reset;
	}
      else
	{
	  page_read_queue_add (buf, itc);
	  if (itc->itc_landed && buf_from  && RWG_WAIT_NO_ENTRY_IF_WAIT  != max_change)
	    {
	      itc->itc_to_reset = RWG_WAIT_NO_CHANGE;
	      if (itc->itc_desc_order)
		itc_skip_entry (itc, buf_from);
	      itc_register_safe (itc, buf_from);
	    }
	  if (buf_from && RWG_WAIT_NO_ENTRY_IF_WAIT != max_change)
	    page_leave_inner (buf_from);
	  start_ts = rdtsc ();
	  ITC_SEM_WAIT (itc);
	  ITC_ACT(itc)->da_thread_pg_wait += rdtsc () - start_ts;
	}
    }
  else
    {
      if (!buf->bd_is_write
	  && 0 == buf->bd_readers)
	{
	  if (buf_from)
	    page_leave_inner (buf_from);
	  BD_SET_IS_WRITE (buf, 1);
	  ITC_LEAVE_MAPS (itc);
	  BUF_BOUNDS_CHECK (buf);
	  itc->itc_pl = buf->bd_pl;
	  *buf_ret = buf;
	  BUF_TOUCH (buf);
	  BUF_DBG_ENTER (buf);
	  return itc->itc_to_reset;
	}
      else
	{
	  itc->itc_to_reset = RWG_WAIT_NO_CHANGE;
	  page_write_queue_add (buf, itc);
	  if (itc->itc_landed && buf_from  && RWG_WAIT_NO_ENTRY_IF_WAIT  != max_change)
	    {
	      if (itc->itc_desc_order)
		itc_skip_entry (itc, buf_from);
	      itc_register_safe (itc, buf_from);
	    }
	  if (buf_from && RWG_WAIT_NO_ENTRY_IF_WAIT != max_change)
	    page_leave_inner (buf_from);
	  start_ts = rdtsc();
	  ITC_SEM_WAIT (itc);
	  ITC_ACT(itc)->da_thread_pg_wait += rdtsc () - start_ts;
	}
    }
  if (itc->itc_to_reset <= max_change && itc->itc_to_reset != RWG_WAIT_NO_ENTRY_IF_WAIT)
    {
      *buf_ret = buf;
      AL_WAIT_SET_WRITER (buf);
      BUF_BOUNDS_CHECK (buf);
      BUF_TOUCH (buf);
    }
  else
    *buf_ret = NULL;
  ASSERT_OUTSIDE_MAPS (itc);
  return (itc->itc_to_reset);
}


void
page_release_read (buffer_desc_t * buf)
{
  it_cursor_t *waiting = buf->bd_read_waiting;
  it_cursor_t *next;
  buf->bd_read_waiting = NULL;
  while (waiting)
    {
      next = waiting->itc_next_waiting;
      waiting->itc_read_waits++;
      dbg_printf (("Release busted at %ld,\n", buf->bd_page));
      if (waiting->itc_to_reset <= waiting->itc_max_transit_change)
	{
	  BUF_BOUNDS_CHECK (buf);
	  waiting->itc_buf_entered = buf;
	  waiting->itc_pl = buf->bd_pl;
#ifdef ADAPTIVE_LAND
	  assert (PA_WRITE != waiting->itc_dive_mode);
	  ADAPTIVE_READ_INC (waiting, buf);
	  if (PA_WRITE == waiting->itc_dive_mode)
	    {
	      /* if adaptive landing made this a write, then free no more cursors. */
#ifdef PAGE_DEBUG
	      buf->bd_writer = waiting->itc_thread;
#endif
	      buf->bd_read_waiting = next;
	      semaphore_leave (waiting->itc_thread->thr_sem);
	      return;
	    }
#else
	  buf->bd_readers++;
#endif
	}
      else
	{
	  rdbg_printf (("pw reset itc %p chg %d max %d landed %d a for %d itc_page %d \n",
			waiting, (int) waiting->itc_to_reset,
			(int) waiting->itc_max_transit_change, (int)waiting->itc_landed,
			buf->bd_page, waiting->itc_page));
	  if (RWG_WAIT_NO_ENTRY_IF_WAIT == waiting->itc_max_transit_change)
	    waiting->itc_to_reset = RWG_WAIT_NO_ENTRY_IF_WAIT;
	  /*the point above is to set the itc_to_reset to indicate wait+no entry.  The case where there is entry with no wait has itc_to_reset set to RWG_NO_WAIT */
	  waiting->itc_buf_entered = NULL;
	  TC (tc_page_wait_reset);
	}
      semaphore_leave (waiting->itc_thread->thr_sem);
      waiting = next;
    }
}

#define W_RELEASED 1
#define W_NOT_RELEASED 0

int
page_release_writes (buffer_desc_t * buf)
{
  it_cursor_t *waiting = buf->bd_write_waiting;
  while (waiting)
    {
      it_cursor_t *next = waiting->itc_next_waiting;
      waiting->itc_write_waits++;
      if (waiting->itc_to_reset <= waiting->itc_max_transit_change)
	{
	  rdbg_printf (("pw release write itc %x chg %d max %d w for %ld \n",
			waiting, (int) waiting->itc_to_reset, (int) waiting->itc_max_transit_change, buf->bd_page));
	  waiting->itc_buf_entered = buf;
	  BUF_BOUNDS_CHECK (buf);
	  waiting->itc_pl = buf->bd_pl;
	  BD_SET_IS_WRITE (buf, 1);
#ifdef PAGE_DEBUG
	  buf->bd_writer = waiting->itc_thread;
#endif
	  buf->bd_write_waiting = next;
	  semaphore_leave (waiting->itc_thread->thr_sem);
	  return W_RELEASED;
	}
      else
	{
	  rdbg_printf (("pw reset itc %x chg %d max %d landed %d w for %ld itc_page %ld \n",
			waiting, (int) waiting->itc_to_reset,
			(int) waiting->itc_max_transit_change, (int)waiting->itc_landed,
			buf->bd_page, waiting->itc_page));
	  TC (tc_page_wait_reset);
	  if (RWG_WAIT_NO_ENTRY_IF_WAIT == waiting->itc_max_transit_change)
	    waiting->itc_to_reset = RWG_WAIT_NO_ENTRY_IF_WAIT;
	  /*the point above is to set the itc_to_reset to indicate wait+no entry.  The case where there is entry with no wait has itc_to_reset set to RWG_NO_WAIT */
	  waiting->itc_buf_entered = NULL;
	  buf->bd_write_waiting = next;
	  semaphore_leave (waiting->itc_thread->thr_sem);
	}
      waiting = next;
    }
  buf->bd_write_waiting = NULL;
  return W_NOT_RELEASED;
}


int enable_col_leave_check = 0;

void
DBGP_NAME (page_leave_inner) (DBGP_PARAMS buffer_desc_t * buf)
{
#ifdef MTX_DEBUG
  if (!is_crash_dump && buf->bd_tree)
    ASSERT_IN_MAP (buf->bd_tree, buf->bd_page);
#endif
  BUF_BOUNDS_CHECK(buf);
#ifdef PAGE_DEBUG
  if (enable_col_leave_check && buf->bd_buffer && DPF_INDEX == SHORT_REF (buf->bd_buffer + DP_FLAGS) && buf->bd_tree && buf->bd_tree->it_key && buf->bd_tree->it_key->key_is_col
      &&   BUF_SEEMS_LEAF (buf, buf->bd_content_map))
    {
      it_map_t * itm = IT_DP_MAP (buf->bd_tree, buf->bd_page);
      mutex_leave (&itm->itm_mtx);
      buf_ce_check (buf);
      mutex_enter (&itm->itm_mtx);
    }
#endif
  BUF_DBG_LEAVE (buf);
  if (buf->bd_readers)
    {
      buf->bd_readers--;
      if (0 == buf->bd_readers)
	{
	  if (!buf->bd_write_waiting || W_NOT_RELEASED == page_release_writes (buf))
	    {
	      if (buf->bd_read_waiting)
		page_release_read (buf);
	    }
	}
      else if (buf->bd_readers < 0)
	GPF_T;			/* Negative readers */
    }
  else
    {
      if (!buf->bd_is_write)
	GPF_T1 ("Leaving a buffer with neither read or write access");
      BD_SET_IS_WRITE (buf, 0);
      if (!buf->bd_write_waiting || W_NOT_RELEASED == page_release_writes (buf))
	{
	  if (buf->bd_read_waiting)
	    page_release_read (buf);
	}
    }
  /* set the space to null for deld buffer after all else.  This is so that buffer replacement will wait for the page map so it does not do dirty reads on intermediate states of releasing the buffer */
}


void
page_leave_as_deleted (buffer_desc_t * buf)
{
  buf_set_last (buf);
  page_mark_change (buf, RWG_WAIT_ANY + 1);
  page_leave_inner (buf);
  if (buf->bd_is_write || buf->bd_readers)
    GPF_T1 ("when a buffer was left for deleted, none of the waiting itc should have entered");
  buf->bd_tree = NULL;
  buf->bd_page = 0;
}


void
page_mark_change (buffer_desc_t * buf, int change)
{
  it_cursor_t *itc;
  if (!buf->bd_is_write && !buf->bd_readers)
    GPF_T1 ("Must have read or write access on buf to mark change");
  ASSERT_IN_MAP (buf->bd_tree, buf->bd_page);
  for (itc = buf->bd_write_waiting; itc; itc = itc->itc_next_waiting)
    itc->itc_to_reset = MAX (itc->itc_to_reset, change);
  for (itc = buf->bd_read_waiting; itc; itc = itc->itc_next_waiting)
    itc->itc_to_reset = MAX (itc->itc_to_reset, change);
}


void
page_write_queue_add (buffer_desc_t * buf, it_cursor_t * itc)
{
  it_cursor_t **last = &buf->bd_write_waiting;
  ITC_KEY_INC (itc, key_write_wait);
  TC (tc_write_wait);
  if (!buf->bd_being_read && buf->bd_is_write && !buf->bd_iq && buf->bd_buffer && DPF_COLUMN == SHORT_REF (buf->bd_buffer + DP_FLAGS))
    log_error ("Write wait on column page %d.  Waits should be on the index leaf page, except when col page is held for read by background write", buf->bd_page);
  itc->itc_thread = THREAD_CURRENT_THREAD;
  while (*last)
    last = &((*last)->itc_next_waiting);
  *last = itc;
  itc->itc_next_waiting = NULL;
}

void
page_read_queue_add (buffer_desc_t * buf, it_cursor_t * itc)
{
  TC (tc_read_wait);
  ASSERT_IN_MTX (&IT_DP_MAP (buf->bd_tree, buf->bd_page)->itm_mtx);
  ITC_KEY_INC (itc, key_read_wait);
  if (!buf->bd_being_read && buf->bd_buffer && DPF_COLUMN == SHORT_REF (buf->bd_buffer + DP_FLAGS)) log_error ("Read wait on column page %d.  Waits should be on the index leaf page", buf->bd_page);
  itc->itc_thread = THREAD_CURRENT_THREAD;
  itc->itc_next_waiting = buf->bd_read_waiting;
  buf->bd_read_waiting = itc;
}



#if 0

void
it_clear_right_edge_cache (dp_addr_t dp)
{
  dbe_key_t *key = (dbe_key_t *) gethash (DP_ADDR2VOID (dp), it->it_right_edges);
  if (key)
    {
      key->key_is_last_right_edge = 0;
      remhash (DP_ADDR2VOID (dp), it->it_right_edges);
    }
}


void
itc_set_right_edge_cache (it_cursor_t * itc)
{
  if (itc->itc_search_mode == SM_INSERT && itc->itc_is_index_end)
    {
      itc_clear_tight_edge_cache (itc->itc_page);
    }
}
#endif


int
itc_try_land (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  uint64 start_ts;
  buffer_desc_t *buf = *buf_ret;
  itc->itc_rows_on_leaves += buf->bd_content_map->pm_count;
  if (PA_READ != itc->itc_dive_mode)
    {
      ITC_MARK_LANDED (itc);
      itc->itc_landed = 1;
      itc->itc_to_reset = RWG_NO_WAIT;
      return RWG_NO_WAIT;
    }
  if (buf->bd_is_write)
    GPF_T1 ("Can't land while buffer being written");

  itc->itc_to_reset = RWG_NO_WAIT;
  ITC_IN_KNOWN_MAP (itc, itc->itc_page);

  if (buf->bd_readers > 1)
    {
      /* the page is being read also by others.  Must wait.  It is in principle possible that a write itc comes here, via transact, via reenter, via landed transit.
       * The write itc would come in first.  It could split or delete the page.  Hence, if transit change is more than data, just reset.
       * Registration is not needed here since position does not have to be maintained since any change that would move the itc results in reset */
      TC (tc_try_land_write);
      ITC_KEY_INC (itc, key_landing_wait);
      itc->itc_to_reset = RWG_NO_WAIT;
      itc->itc_max_transit_change = RWG_WAIT_DATA;
      page_write_queue_add (buf, itc);
      buf->bd_readers--;
      start_ts = rdtsc ();
      ITC_SEM_WAIT (itc);
      ITC_ACT (itc)->da_thread_pg_wait += rdtsc () - start_ts;
      if (itc->itc_to_reset <= RWG_WAIT_DATA)
	{
#ifdef PAGE_DEBUG
	  buf->bd_writer = THREAD_CURRENT_THREAD;
#endif
	  itc->itc_pl = buf->bd_pl;
	  itc->itc_landed = 1;
	}
      else
	TC (tc_try_land_reset);
    }
  else
    {
      buf->bd_readers = 0;
      BD_SET_IS_WRITE (buf, 1);
      ITC_FIND_PL (itc, buf);
      ITC_LEAVE_MAP_NC (itc);
      itc->itc_landed = 1;
    }
  if (itc->itc_landed)
    {
      dbe_key_t *key = itc->itc_insert_key;
      if (key)
	{
	  ITC_MARK_LANDED (itc);
	  if (itc->itc_page == key->key_last_page)
	    {
	      key->key_n_last_page_hits++;
	      key->key_total_last_page_hits++;
	    }
	  else
	    {
	      key->key_last_page = itc->itc_page;
	      key->key_n_last_page_hits = 0;
	    }
	}
    }
  return (itc->itc_to_reset);
}


buffer_desc_t *
pl_enter (placeholder_t * pl, it_cursor_t * ctl_itc)
{
  /* get the buffer that corresponds to the pl.  The pl may move anytime.  On return, the buffer is on excl access and the pl agrees with the buffer.
   * ctl_itc is used for entry and maps etc.  it can be == pl. */
  buffer_desc_t *buf;
  dp_addr_t volatile target_dp;
  dp_addr_t volatile target_dp_1;
  pl->itc_owns_page  = 0; /* can have committed or moved etc since last on the page */
  if (!pl->itc_is_registered)
    GPF_T1 ("pl must be registered in pl_enter");
retry:
  if (ctl_itc->itc_ltrx && ctl_itc->itc_ltrx->lt_status != LT_CLOSING)
    {
      /* make an exception for closing since deletes inside commit or rollback can call this */
      if (!ctl_itc->itc_fail_context) GPF_T1 ("must have fail ctx in pl_enter");
      CHECK_TRX_DEAD (ctl_itc, NULL, ITC_BUST_CONTINUABLE);
    }

  target_dp_1 = pl->itc_page;
  ITC_IN_KNOWN_MAP (ctl_itc, target_dp_1);
  target_dp = pl->itc_page; /* now it is in the map but it can still move because anybody owning the specific buffer can move it */
  /* check that we are at least in the right map. */
  if (target_dp != target_dp_1)
    {
      ITC_LEAVE_MAP_NC (ctl_itc);
      TC (tc_pl_moved_in_reentry);
      goto retry;
    }
  if (pl->itc_bp.bp_transiting)
    {
      ITC_LEAVE_MAP_NC (ctl_itc);
      TC (tc_enter_transiting_bm_inx);
      virtuoso_sleep (0, 100);
      goto retry;
    }
  buf = pl->itc_buf_registered;
  if (!buf
      || buf->bd_page != target_dp_1)
    {
      /* the buf could just disappear for transit or could have changed so we're no longer in the right map */
      TC (tc_pl_moved_in_reentry);
      ITC_LEAVE_MAP_NC (ctl_itc);
      goto retry;
    }
  if (!buf->bd_is_write && (PA_READ_ONLY == ctl_itc->itc_dive_mode || !buf->bd_readers)
      && BUF_NONE_WAITING (buf))
    {
      if (buf->bd_page != pl->itc_page)
	{
	  if (pl->itc_page == target_dp_1)
	    GPF_T1 ("the registered buf is is a different page than the itc page but the pl has not moved during the reentry");
	  TC (tc_pl_moved_in_reentry);
	  ITC_LEAVE_MAP_NC (ctl_itc);
	  goto retry;
	}
      if (PA_READ_ONLY != ctl_itc->itc_dive_mode)
      BD_SET_IS_WRITE (buf, 1);
      else
	buf->bd_readers++;
      ITC_LEAVE_MAP_NC (ctl_itc);
      return buf;
    }
  ITC_KEY_INC (ctl_itc, key_pl_wait);
  page_wait_access (ctl_itc, target_dp, NULL, &buf, ITC_LANDED_PA (ctl_itc), RWG_WAIT_KEY);
  if (ctl_itc->itc_to_reset > RWG_WAIT_KEY)
    {
      TC (tc_reentry_split);
      if (ctl_itc->itc_must_kill_trx) /* reference to free remap, kill trx */
	{
	  ctl_itc->itc_must_kill_trx = 0;
	  if (!wi_inst.wi_checkpoint_atomic && ctl_itc->itc_ltrx)
	    itc_bust_this_trx (ctl_itc, NULL, ITC_BUST_THROW);
	}
      goto retry;
    }
  if (PF_OF_DELETED == buf)
    {
      if (pl->itc_page == target_dp)
	GPF_T1 ("reentry of registered on deld page and the pl had not moved");
      ITC_LEAVE_MAP_NC (ctl_itc);
      goto retry;
    }
  if (pl->itc_page != target_dp)
    {
      TC (tc_pl_moved_in_reentry);
      ITC_LEAVE_MAPS (ctl_itc);
      page_leave_outside_map (buf);
      goto retry;
    }
  return buf;
}


buffer_desc_t *
page_reenter_excl (it_cursor_t * itc)
{
  buffer_desc_t *buf;
  buf = pl_enter ((placeholder_t *) itc, itc);
  itc_unregister_inner (itc, buf, 0);
  ITC_FIND_PL (itc, buf);
  ITC_LEAVE_MAPS (itc); /* only because itc_find_pl may enter ifdef mtx_debug */
  /* the itc_page, itc_map_pos are correct since it was registered */
  return buf;
}


void
itc_fix_back_link (it_cursor_t * itc, buffer_desc_t ** buf, dp_addr_t dp_from,
		   buffer_desc_t * old_buf, dp_addr_t back_link, int was_after_wait)
{
  if (itc->itc_read_waits || itc->itc_write_waits)
    was_after_wait = 1;

  rdbg_printf ((
		"Bad parent link in %ld, coming from %ld, parent link = %ld.\n",
		(*buf)->bd_page, old_buf->bd_page, back_link));
  if (1 || was_after_wait)
    {
      int was_landed = itc->itc_landed, pos;
      buffer_desc_t * parent;
      if (!itc->itc_landed)
	{
	  itc_try_land (itc, buf);
	  if (!itc->itc_landed)
	    {
	      *buf = itc_reset (itc);
	      return;
	    }
	}
      parent = itc_write_parent (itc, *buf);
      if ((!parent && was_landed) || PF_OF_DELETED == parent)
	return;
      if (!parent)
	{
	  itc_page_leave (itc, *buf);
	  *buf = itc_reset (itc);
	  return;
	}
      pos = page_find_leaf (parent, (*buf)->bd_page);
      if (pos == ITC_AT_END)
	{
	  log_error ("A bad parent link has been detected by looking at the would be parent and finding no leaf pointer.  The pages follow, parent first.");
	  dbg_page_map (parent);
	  dbg_page_map (*buf);
	  if (!correct_parent_links)
	    {
	      log_error ("Consult your documentation on how to recover from "
			 "this situation.  Doe a crush dump and restore or try the autocorrect options in the virtuoso.ini file");
	      GPF_T1 ("fatal consistency check failure");
	    }
	  LONG_SET ((*buf)->bd_buffer + DP_PARENT, dp_from);
	  (*buf)->bd_is_dirty = 1;
	  log_info ("Bad parent link corrected");
	}
      page_leave_outside_map (parent);
      if (!was_landed)
	{
	  itc_page_leave (itc, *buf);
	  *buf = itc_reset (itc);
	}
      return;
    }
}


long tc_excl_dive;


void
itc_right_leaf (it_cursor_t * itc, buffer_desc_t * buf)
{
  page_map_t * pm = buf->bd_content_map;
  if (itc->itc_map_pos == pm->pm_count - 1)
    {
      if (ITC_RL_INIT == itc->itc_keep_right_leaf)
	itc->itc_keep_right_leaf = ITC_RIGHT_EDGE;
    }
  else
    {
      page_row_bm (buf, itc->itc_map_pos + 1, itc->itc_right_leaf_key, RO_LEAF, NULL);
      itc->itc_keep_right_leaf = ITC_RL_LEAF;
    }
}


void
itc_dive_transit (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t to)
{
  buffer_desc_t *old_buf = *buf_ret;
  int waited = 0;
  buffer_desc_t *volatile dest_buf = NULL;
  index_tree_t * tree = itc->itc_tree;
  dk_hash_t * ht;
  dp_addr_t dp_from = itc->itc_page, back_link;
  it_map_t * itm1 = IT_DP_MAP (tree, dp_from);
  it_map_t * itm2 = IT_DP_MAP (tree, to);
  /* cache place, use when looking for next sibling *
   *itc->itc_parent_page = itc->itc_page;
   *itc->itc_pos_on_parent = itc->itc_position;
   */

  if (itc->itc_keep_right_leaf)
    itc_right_leaf (itc, *buf_ret);
  if (PA_WRITE == itc->itc_dive_mode)
    {
      TC (tc_excl_dive);
      goto general_case;
    }
  ht = &itm2->itm_dp_to_buf;
  if (itm2 <= itm1)
    {
      /* here we lock dest mtx first, translate the address and last of all get the source mtx and dec the read */
      mutex_enter (&itm2->itm_mtx);
      GETHASH (DP_ADDR2VOID (to), ht, dest_buf, not_found_2_1);
      if (dest_buf->bd_is_write || !BUF_NONE_WAITING (dest_buf))
	goto not_found_2_1;
      if (itm1 != itm2)
	mutex_enter (&itm1->itm_mtx);
      ADAPTIVE_READ_INC (itc, dest_buf);
      if (itm1 != itm2)
	mutex_leave (&itm2->itm_mtx);
      if (BUF_NONE_WAITING (old_buf))
	{
	  BUF_DBG_LEAVE_INL (old_buf);
	old_buf->bd_readers--;
	}
      else
	page_leave_inner (old_buf);
      /* If the itms were different, the target itm is already exited */
      mutex_leave (&itm1->itm_mtx);
      itc->itc_pl = dest_buf->bd_pl;
	*buf_ret = dest_buf;
      goto check_link;
    not_found_2_1:
      itc->itc_itm1 = itm2;
      if (itm1 != itm2)
	{
	  itc->itc_itm2 = itm1;
	  mutex_enter (&itm1->itm_mtx);
	}
      goto general_case;
    }
  else
#if DIVE_WDEAD
    {
      /* now the mtx for the destination is higher than for the source.  We lock in wrong order and reverse if we can't have the second mtx */
      mutex_enter (&itm2->itm_mtx);
      GETHASH (DP_ADDR2VOID (to), ht, dest_buf, not_found_1_2);
      if (dest_buf->bd_is_write || !BUF_NONE_WAITING (dest_buf))
	goto not_found_1_2;
      if (!mutex_try_enter (&itm1->itm_mtx))
	goto dive_deadlock;
      dest_buf->bd_readers++;
      mutex_leave (&itm2->itm_mtx);
      if (BUF_NONE_WAITING (old_buf))
	{
	  BUF_DBG_LEAVE_INL (old_buf);
	old_buf->bd_readers--;
	}
      else
	page_leave_inner (old_buf);
      mutex_leave (&itm1->itm_mtx);
      *buf_ret = dest_buf;
      goto check_link;
    not_found_1_2:
      if (mutex_try_enter (&itm1->itm_mtx))
	{
	  itc->itc_itm1 = itm1;
	  itc->itc_itm2 = itm2;
	  /* we own both mtxs and itc->itm* is set, sp [page_wait_access will not enter transit again */
	  goto general_case;
	}
      dive_deadlock:
      /* we tried lock the higher first and failed to get the lower. */
      mutex_leave (&itm2->itm_mtx);
      TC (tc_dive_would_deadlock);
      /* itc->itm1 and 2 are NULL, we are not inside any mtx, page_wait_access will then enter the transit in the general case */
      goto general_case;
    }
#else
    {
      /* now the mtx for the destination is higher than for the source.  */
      mutex_enter (&itm1->itm_mtx);
      mutex_enter (&itm2->itm_mtx);
      GETHASH (DP_ADDR2VOID (to), ht, dest_buf, not_found_1_2);
      if (dest_buf->bd_is_write || !BUF_NONE_WAITING (dest_buf))
	goto not_found_1_2;
      ADAPTIVE_READ_INC (itc, dest_buf);
      mutex_leave (&itm2->itm_mtx);
      if (BUF_NONE_WAITING (old_buf))
	{
	  BUF_DBG_LEAVE_INL (old_buf);
	old_buf->bd_readers--;
	}
      else
	page_leave_inner (old_buf);
      mutex_leave (&itm1->itm_mtx);
      *buf_ret = dest_buf;
      itc->itc_pl = dest_buf->bd_pl;
      goto check_link;
    not_found_1_2:
      itc->itc_itm1 = itm1;
      itc->itc_itm2 = itm2;
      /* we own both mtxs and itc->itm* is set, sp [page_wait_access will not enter transit again */
    }
#endif

 general_case:
    page_wait_access (itc, to, *buf_ret, buf_ret, ITC_DIVE_PA (itc), RWG_WAIT_KEY);
  if (itc->itc_to_reset >= RWG_WAIT_SPLIT)
    {
      TC (tc_dive_split);
      *buf_ret = itc_reset (itc);
      itc->itc_read_waits += 1000;
      return;
    }
  if (itc->itc_read_waits || itc->itc_write_waits)
    waited = 1;
  dest_buf = *buf_ret;
  goto check_link_2;
 check_link:
  BUF_TOUCH (dest_buf);
  BUF_DBG_ENTER_INL (dest_buf);
 check_link_2:
  back_link = LONG_REF (dest_buf->bd_buffer + DP_PARENT);
  itc->itc_page = dest_buf->bd_page;
  if (back_link != dp_from)
    itc_fix_back_link (itc, buf_ret, dp_from, old_buf, back_link, waited);
  itc->itc_map_pos = ITC_AT_END;
#ifndef NDEBUG
  if ((*buf_ret)->bd_readers <= 0 && !(*buf_ret)->bd_is_write)
    GPF_T1 ("dive transit ends in bd_readers <= 0 or is_write > 0");
  if ((*buf_ret)->bd_is_dirty && (*buf_ret)->bd_physical_page != (*buf_ret)->bd_page)
    {
      it_map_t * itm = IT_DP_MAP (tree, to);
      mutex_enter (&itm->itm_mtx);
      if (!gethash ((void*)(void*)(ptrlong)to, &itm->itm_remap))
	GPF_T;
      mutex_leave (&itm->itm_mtx);
    }
#endif
}


void
DBGP_NAME (itc_landed_down_transit) (DBGP_PARAMS it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t to)
{
  buffer_desc_t *old_buf = *buf_ret;
  int waited = 0;
  dp_addr_t dp_from = itc->itc_page, back_link;
  page_map_t * pm;
  /* itc->itc_parent_page = itc->itc_page;
   * itc->itc_pos_on_parent = itc->itc_position; */
  /* commented out.  cache place, use when looking for next sibling */

#ifndef NDEBUG
  if (PA_READ_ONLY != itc->itc_dive_mode && !old_buf->bd_is_write) GPF_T1 ("landed transit got no write");
#endif
  itc->itc_is_on_row = 1;
  DBGP_NAME (page_wait_access) (DBGP_ARGS itc, to, *buf_ret, buf_ret, ITC_LANDED_PA (itc), RWG_NO_WAIT);
  if (itc->itc_to_reset > RWG_NO_WAIT)
    {
      /* there was a wait and the itc was registered.  To unregister, reenter the page and go back to itc_search to see where to goo. The leaf could have been deld or split */
      TC (tc_dtrans_split);
      *buf_ret = page_reenter_excl (itc);
      if (itc->itc_desc_order
	  && (itc->itc_is_on_row || ITC_AT_END == itc->itc_map_pos))
	{
	  /* The itrc was registered on the entry to the right of the leaf targeted.  If the leaf targeted was the rightmost entry, the itc was registered at 0, meaning past end.  So if it was 0, put the itc to the rightmost, else one to the left of the registered pos. If the registered pos was the leftmost, then going one to the left gives 0, which is OK since itc_search will then go to the parent */
	  if (ITC_AT_END == itc->itc_map_pos)
	    {
	      page_map_t * pm = (*buf_ret)->bd_content_map;
	      itc->itc_map_pos = pm->pm_count - 1;
	    }
	  else
	    itc_prev_entry (itc, *buf_ret);
	}
      return;
    }
  if (itc->itc_is_registered)
    GPF_T1 ("itc in down transit registered even if no wait");
  itc->itc_page = (*buf_ret)->bd_page;
#ifdef NEW_HASH
  itc_hi_source_page_used (itc, itc->itc_page);
#endif

  ITC_FIND_PL (itc, *buf_ret);
  back_link = LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT);
  if (back_link != dp_from)
    itc_fix_back_link (itc, buf_ret, dp_from, old_buf, back_link, waited);
  ITC_LEAVE_MAPS (itc);
  itc->itc_nth_seq_page++;
  pm = (*buf_ret)->bd_content_map;
  if (itc->itc_desc_order)
        itc->itc_map_pos = pm->pm_count - 1;
  else
    itc->itc_map_pos = 0;
  if (BUF_SEEMS_LEAF ((*buf_ret), pm))
    {
      itc->itc_rows_on_leaves += pm->pm_count;
      ITC_MARK_ROW (itc);
      itc_check_col_prefetch (itc, *buf_ret);
    }
  else if (itc->itc_col_prefetch)
    itc_set_siblings (itc, *buf_ret, 0);
}

void
DBGP_NAME (itc_down_transit) (DBGP_PARAMS it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t to)
{
  if (itc->itc_landed)
    DBGP_NAME (itc_landed_down_transit) (DBGP_ARGS itc, buf_ret, to);
  else
    itc_dive_transit (itc, buf_ret, to);
}


int
itc_up_transit (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  buffer_desc_t * parent_buf = NULL;
  int up_ctr = 0, deld_ctr = 0;
  dp_addr_t up;
  volatile dp_addr_t * up_field;
  up_field = (dp_addr_t *) ((*buf_ret)->bd_buffer + DP_PARENT);
up_again:
  up = LONG_REF (up_field);
  ITC_IN_TRANSIT (itc, up, (*buf_ret)->bd_page)
    if (! LONG_REF (up_field))
      {
	/* The parent got deld by itc_single_leaf_delete while waiting for parent access */
	ITC_LEAVE_MAPS (itc);
	return DVC_INDEX_END;
      }
  if (LONG_REF (up_field) != up)
      {
	ITC_LEAVE_MAPS(itc);
	TC (tc_up_transit_parent_change);
	goto up_again;
      }
    parent_buf = NULL;
    page_wait_access (itc, up, *buf_ret, &parent_buf, ITC_LANDED_PA (itc), RWG_WAIT_NO_ENTRY_IF_WAIT);
  /* the no entry case applies only to a wait. Also, if there is a wait, the original buffer will stay occupied by this itc.
  * So if we got no buffer, there was a wait and if we got one the transit had no wait but could have disk read. */
    if (PF_OF_DELETED == parent_buf)
      {
	deld_ctr++;
	log_info ("up transit to deleted parent %d on %s", up, itc->itc_insert_key->key_name);
	if (deld_ctr > 2)
	  return DVC_INDEX_END;
	goto up_again;
      }
  if (!parent_buf)
    {
      up_ctr ++;
      rdbg_printf (("up transit wait itc %x from %ld to %ld\n", itc, (*buf_ret)->bd_page, up));
      TC (tc_up_transit_wait);
      goto up_again;
    }
  *buf_ret = parent_buf;
#ifndef NDEBUG
  if (PA_READ_ONLY != itc->itc_dive_mode && !(*buf_ret)->bd_is_write)
    GPF_T1 ("up transit leaves with no write on buffer");
#endif
  itc->itc_pl = parent_buf->bd_pl;
  itc->itc_page = parent_buf->bd_page;
#ifdef NEW_HASH
  itc_hi_source_page_used (itc, itc->itc_page);
#endif
  itc->itc_map_pos = ITC_AT_END;
  return DVC_MATCH;
}

void
itc_root_cache_enter (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t leaf)
{
  index_tree_t * tree = itc->itc_tree;
  it_map_t * itm = IT_DP_MAP (tree, leaf);
  buffer_desc_t * buf = NULL;
  if (!leaf)
    {
      tree->it_is_single_page = 1;
      *buf_ret = NULL;
    }
  if (itc->itc_keep_right_leaf)
    itc_right_leaf (itc, *buf_ret);

  mutex_enter (&itm->itm_mtx);
  if (tree->it_root_image_version != itc->itc_root_image_version)
    {
      mutex_leave (&itm->itm_mtx);
      *buf_ret = NULL;
      TC (tc_root_image_miss);
      return;
    }
  GETHASH (DP_ADDR2VOID (leaf), (&itm->itm_dp_to_buf), buf, not_present);
  if (buf && !buf->bd_is_write && !buf->bd_being_read && BUF_NONE_WAITING (buf))
    {
      ADAPTIVE_READ_INC (itc, buf);
      mutex_leave (&itm->itm_mtx);
      buf->bd_timestamp = buf->bd_pool->bp_ts;
      *buf_ret = buf;
      itc->itc_pl = buf->bd_pl;
      itc->itc_page = buf->bd_page;
      return;
    }
 not_present:
  if (!buf)
    {
      dp_addr_t remap;
      IT_DP_REMAP (tree, leaf, remap);
      if (DP_DELETED == remap)
	{
	  TC (tc_root_image_ref_deleted);
	  mutex_leave (&itm->itm_mtx);
	  *buf_ret = NULL;
	  return;
	}
    }
  itc->itc_itm1 = itm;
  page_wait_access (itc, leaf, NULL, buf_ret, PA_READ, RWG_WAIT_KEY);
  if (tree->it_root_image_version != itc->itc_root_image_version)
    {
      TC (tc_root_image_miss);
      if (itc->itc_to_reset <= RWG_WAIT_KEY)
	page_leave_outside_map (*buf_ret);
      *buf_ret = NULL;
      return;
    }
  if (itc->itc_to_reset <= RWG_WAIT_KEY)
    {
      itc->itc_page = (*buf_ret)->bd_page;
      return;
    }
  *buf_ret = NULL;
}


buffer_desc_t *
itc_root_image_lookup (it_cursor_t * itc)
{
  index_tree_t * tree = itc->itc_tree;
  buffer_desc_t * volatile image = tree->it_root_image;
  volatile int start_version = tree->it_root_image_version;
  buffer_desc_t * rc_buf = NULL;
  if (!start_version || !image)
    return NULL;
  itc->itc_root_image_version = start_version;
  rc_buf = image;
  if (!itc->itc_no_bitmap && itc->itc_insert_key && itc->itc_insert_key->key_is_bitmap)
    itc_init_bm_search (itc);

  if (!itc->itc_key_spec.ksp_key_cmp)
    itc->itc_key_spec.ksp_key_cmp = SM_READ == itc->itc_search_mode ? pg_key_compare : pg_insert_key_compare;

  if (itc->itc_search_mode == SM_READ)
    itc_page_split_search (itc, &rc_buf);
  else
    itc_page_insert_search (itc, &rc_buf);
  if (rc_buf && rc_buf->bd_is_ro_cache)
    {
      tree->it_is_single_page = 1;
      return NULL;
    }
  return rc_buf;
}


void
it_new_root_image (index_tree_t * tree, buffer_desc_t * buf)
{
  int v, new_map_sz;
  buffer_desc_t * new_image;
  dk_mutex_t * root_cache_replace_mtx = &tree->it_maps[0].itm_mtx;
  page_map_t * map = buf->bd_content_map;
  if (BUF_SEEMS_LEAF (buf, map))
    {
      tree->it_is_single_page = 1;
      return;
    }
  mutex_enter (root_cache_replace_mtx);
  if (tree->it_root_image_version
      || buf->bd_page != tree->it_root)
    {
      mutex_leave (root_cache_replace_mtx);
      return;
    }
  v = ++tree->it_root_version_ctr;
  if (!v)
    tree->it_root_version_ctr = v = 1;
  new_image = buffer_allocate (DPF_INDEX);
  new_image->bd_is_ro_cache = 1;
  memcpy (new_image->bd_buffer, buf->bd_buffer, MIN (buf->bd_content_map->pm_filled_to + MAX_KV_GAP_BYTES, PAGE_SZ));
  new_image->bd_tree = tree;
  /* keep the actual size of the new map.  It may be that the old map's size if greater than the size implied by its count */
  new_image->bd_content_map = pm_get (new_image, (PM_SIZE (buf->bd_content_map->pm_count)));
  new_map_sz = new_image->bd_content_map->pm_size;
  memcpy (new_image->bd_content_map, buf->bd_content_map, PM_ENTRIES_OFFSET + buf->bd_content_map->pm_count * sizeof (short));
  new_image->bd_content_map->pm_size = new_map_sz;
  tree->it_root_image = new_image;
  tree->it_root_image_version = v;
  mutex_leave (root_cache_replace_mtx);
}

buffer_desc_t * old_root_images;
dk_mutex_t * old_roots_mtx;


void
it_root_image_invalidate (index_tree_t * tree)
{
  /* this is serialized on having write on the confirmed root */
  buffer_desc_t * old_image;
  tree->it_root_image_version = 0;
  if ((old_image = tree->it_root_image))
    {
      old_image->bd_timestamp = approx_msec_real_time ();
      tree->it_root_image = NULL;
      mutex_enter (old_roots_mtx);
      old_image->bd_next = old_root_images;
      old_root_images = old_image;
      mutex_leave (old_roots_mtx);
    }
}


buffer_desc_t *
DBGP_NAME (itc_reset) (DBGP_PARAMS it_cursor_t * it)
{
  /* Enter to root in read mode and return the buffer */
  buffer_desc_t *buf;
  index_tree_t * tree = it->itc_tree;
  dp_addr_t dp, back_link;
  it->itc_landed = 0;
  it->itc_prev_split_search_res = 0;
  it->itc_split_search_res = 0;
  it->itc_bm_insert = 0;
  it->itc_siblings_parent = 0;
  if (it->itc_keep_right_leaf)
    it->itc_keep_right_leaf = ITC_RL_INIT;
  it->itc_is_on_row = 0;
  it->itc_owns_page = 0;
  it->itc_nth_seq_page = 0;
  it->itc_n_lock_escalations = 0;
  it->itc_ra_root_fill = 0;
  it->itc_n_reads = 0;
  it->itc_at_data_level = 0;

  if (it->itc_tree->it_hi)
    {
      if (it->itc_is_registered)
	GPF_T1 ("should not be registered when resetting to a hi");
      ITC_IN_KNOWN_MAP (it, it->itc_tree->it_hash_first);
        DBGP_NAME (page_wait_access) (DBGP_ARGS it, it->itc_tree->it_hash_first, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
	ITC_LEAVE_MAPS (it);
	it->itc_map_pos = DP_DATA + HASH_HEAD_LEN; /* offset into the page, not inx of page map */
      it->itc_page = buf->bd_page;
      it->itc_landed = 1;
	return buf;
    }

  if (it->itc_is_registered)
    {
      itc_unregister (it);
    }
  if (PA_READ_ONLY != it->itc_dive_mode)
    it->itc_dive_mode = PA_READ;
  if (tree->it_key->key_is_col)
    {
      if (!it->itc_is_col)
	itc_col_init (it);
      it->itc_col_row = COL_NO_ROW; /* after unredgister, reentry in set by plh might set itc_col_row */
    }
  else if (it->itc_is_col)
    itc_col_free (it);
  if (tree->it_root_image &&  RANDOM_SEARCH_OFF == it->itc_random_search)
    {
      buf = itc_root_image_lookup (it);
      if (buf)
	return buf;
    }
  if ((PA_READ == it->itc_dive_mode && tree->it_is_single_page )
      || (tree->it_key->key_is_geo && SM_INSERT == it->itc_search_mode)
    )
    it->itc_dive_mode = PA_WRITE;

  for (;;)
    {
      ITC_IN_VOLATILE_MAP (it, tree->it_root);
      dp = tree->it_root;
      buf = tree->it_root_buf;
      /* if we are in the confirmed map of dp in tree and buf has this dp and this tree, then it is safe since this can only change in another thread holding this same map */
      if (buf && buf->bd_page == dp && buf->bd_tree == tree
	  &&BUF_NONE_WAITING (buf))
	{
	  if (PA_WRITE != it->itc_dive_mode)
	    {
	      if (!buf->bd_is_write)
		{
		  buf->bd_readers++;
		  ITC_LEAVE_MAP_NC (it);
		  it->itc_pl = buf->bd_pl;
		  break;
		}
	    }
	  else
	    {
	      if (!buf->bd_is_write && !buf->bd_readers)
		{
		  BD_SET_IS_WRITE (buf, 1);
		  ITC_LEAVE_MAP_NC (it);
		  it->itc_pl = buf->bd_pl;
		  break;
		}
	    }
	}
      TC (tc_root_cache_miss);
      DBGP_NAME (page_wait_access) (DBGP_ARGS it, dp, NULL, &buf, ITC_DIVE_PA (it), RWG_WAIT_KEY);
      if (buf == PF_OF_DELETED)
	GPF_T1 ("The root page of an index is free do a crash dump for recovery.");
      if (it->itc_to_reset > RWG_WAIT_KEY)
	continue;
      tree->it_root_buf = buf;
      break;
    }
  BUF_TOUCH (buf);
  if (!tree->it_is_single_page && !tree->it_root_image_version
      && tree->it_key->key_id != KI_TEMP
      && !tree->it_key->key_is_geo
     )
    {
      it_new_root_image (tree, buf);
    }
  back_link = LONG_REF (buf->bd_buffer + DP_PARENT);
  if (back_link)
    {
      log_error ("Bad parent link in the tree start page %ld, parent link=%ld."
		 " Please do a dump and restore.",
		 dp, back_link);
    }
  it->itc_page = dp;
#ifdef NEW_HASH
  itc_hi_source_page_used (it, it->itc_page);
#endif
  if (!it->itc_no_bitmap && it->itc_insert_key && it->itc_insert_key->key_is_bitmap)
    itc_init_bm_search (it);
  return buf;
}



buffer_desc_t *
itc_write_parent (it_cursor_t * itc,buffer_desc_t * buf)
{
  /* in insert split, in delete, in single leaf node delete.
   * This gets write access on buf's parent without leaving the buf.
   * If the buf is root, NULL is returned.  Otherwise this will always succeed. */
  int retry_ctr = 0;
  volatile dp_addr_t * parent_field = (dp_addr_t*) (buf->bd_buffer + DP_PARENT);
  buffer_desc_t * parent_buf;
  for (;;)
    {
      dp_addr_t parent = LONG_REF (parent_field);
      if (!parent)
	return NULL;
      ITC_IN_TRANSIT (itc, itc->itc_page, parent);
      if (LONG_REF (parent_field) != parent)
	{
	  ITC_LEAVE_MAPS (itc);
	  continue;
    }
      page_wait_access (itc, parent, NULL, &parent_buf, PA_WRITE, RWG_WAIT_DATA);
      ITC_LEAVE_MAPS (itc);
      if (itc->itc_to_reset <= RWG_WAIT_DATA)
	break;
      retry_ctr++;
      TC (tc_delete_parent_waits);
      if (PF_OF_DELETED == parent_buf && retry_ctr > 3)
	{
	  ITC_LEAVE_MAPS (itc);
	  return parent_buf;
	}
    }
  if (BUF_NEEDS_DELTA (parent_buf))
    {
      ITC_IN_KNOWN_MAP (itc, parent_buf->bd_page);
      itc_delta_this_buffer (itc, parent_buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (itc);
    }

  if (!LONG_REF (parent_buf->bd_buffer + DP_PARENT))
    {
      TC (tc_root_write);
      it_root_image_invalidate (parent_buf->bd_tree);
    }
  return parent_buf;
}


void
itc_set_parent_link (it_cursor_t * itc, dp_addr_t child_dp, dp_addr_t new_parent)
{
  dp_addr_t prev_dp = itc->itc_page; /* this is usually the parent of the right side.  This is stably occupied, can save w/o registration */
  /* in split of intermediate node, set the parent of nodes now under the right side of the split */
  buffer_desc_t * buf;
 try_again:
  itc->itc_page = child_dp;
  ITC_IN_KNOWN_MAP (itc, child_dp);
  buf = (buffer_desc_t *) gethash (DP_ADDR2VOID (child_dp), &IT_DP_MAP (itc->itc_tree, child_dp)->itm_dp_to_buf);
  if (!buf)
    {
      page_wait_access (itc, child_dp, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
      if (PF_OF_DELETED == buf)
	GPF_T1 ("setting parent of deleted page in split");
      ITC_IN_KNOWN_MAP (itc, buf->bd_page);
      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
      rdbg_printf_2 (("	 After disk read: Parent of L=%d from L=%d to L=%d .\n",
		      buf->bd_page,
		      LONG_REF (buf->bd_buffer + DP_PARENT), new_parent));
      LONG_SET (buf->bd_buffer + DP_PARENT, new_parent);
      buf->bd_is_dirty = 1;

      itc_page_leave (itc, buf);
      itc->itc_page = prev_dp;
      return;
    }
  if (buf->bd_being_read)
    {
      /* this is rare but can happen if there is a reentry that needs to read the child page
       * We must wait until the page really is in and then  be in map and set the parent.  Can't simply request access because this could deadlock with the reentered page wanting to access the parent which is all this time busy.  So this will be a busy wait here.  */
      TC (tc_dp_set_parent_being_read);
      ITC_LEAVE_MAPS (itc);
      rdbg_printf_2 (("Retry after finding buf being read: Parent of L=%d from L=%d to L=%d.\n",
		      buf->bd_page,
		      LONG_REF (buf->bd_buffer + DP_PARENT), new_parent));

      virtuoso_sleep (0, 1000);
      goto try_again;
    }
  /* there is the  buffer, possibly occupied but since this is in the map, it is safe to set
   * the parent.i  It can only be read in up transit or delete while inside the map. */
  itc_delta_this_buffer (itc, buf, DELTA_STAY_INSIDE);
  rdbg_printf_2 (("	Parent of L=%d from L=%d to L=%d.\n",
		  buf->bd_page,
		  LONG_REF (buf->bd_buffer + DP_PARENT), new_parent));
#ifdef PAGE_DEBUG
  {
    /* The thread is in the map of the buffer, hence bd_is_write is stable, can see if need change protection */
    int is_w = buf->bd_is_write;
    if (!is_w)
      BUF_PW (buf);
  LONG_SET (buf->bd_buffer + DP_PARENT, new_parent);
    if (!is_w)
      BUF_PR (buf);
  }
#else
  LONG_SET (buf->bd_buffer + DP_PARENT, new_parent);
#endif
  BUF_TOUCH (buf);
  buf->bd_is_dirty = 1;

  ITC_LEAVE_MAPS (itc);
  itc->itc_page = prev_dp;
}



#define rdbg_printf_2(a)


void
itc_register (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* Called before going through hyperspace. If the gate busts you
     this will be the life line. */
  dk_mutex_t * ro_entered = NULL;
  if (itc->itc_is_registered && itc->itc_buf_registered)
    {
      GPF_T1 ("double registration");
      return;			/* Already registered. */
    }
  if (buf->bd_page != itc->itc_page)
    GPF_T1 ("different itc_page and bd_page in register");
  if (!buf->bd_readers && !buf->bd_is_write)
    GPF_T1 ("must have write or read on the buffer for registration");
  rdbg_printf_2 (("  register itc=%x on L=%d \n", it, it->itc_page));
  itc->itc_is_registered = 1;
  BUF_RO_REG_ENTER (itc, buf);
#if 1
  {
    it_cursor_t * ck = buf->bd_registered;
    while (ck)
      {
	if (itc == ck)
	  GPF_T1 ("double itc registration");
	ck = ck->itc_next_on_page;
      }
  }
#endif

  itc->itc_next_on_page = buf->bd_registered;
  buf->bd_registered = itc;
  itc->itc_buf_registered = buf;
  BUF_RO_REG_LEAVE (itc, buf);
}


void
itc_register_nc (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* Called before going through hyperspace. If the gate busts you
     this will be the life line. */
  dk_mutex_t * ro_entered = NULL;
  if (itc->itc_is_registered && itc->itc_buf_registered)
    {
      GPF_T1 ("double registration");
      return;			/* Already registered. */
    }
  if (buf->bd_page != itc->itc_page)
    GPF_T1 ("different itc_page and bd_page in register");
  if (!buf->bd_readers && !buf->bd_is_write)
    GPF_T1 ("must have write or read on the buffer for registration");
  rdbg_printf_2 (("  register itc=%x on L=%d \n", it, it->itc_page));
  itc->itc_is_registered = 1;
  BUF_RO_REG_ENTER (itc, buf);
  itc->itc_next_on_page = buf->bd_registered;
  buf->bd_registered = itc;
  itc->itc_buf_registered = buf;
  BUF_RO_REG_LEAVE (itc, buf);
}


void
itc_register_safe (it_cursor_t * itc, buffer_desc_t * buf)
{
  if (itc->itc_is_registered && itc->itc_buf_registered)
    {
      GPF_T1 ("double registration");
      return;			/* Already registered. */
    }
  if (buf->bd_page != itc->itc_page)
    GPF_T1 ("different itc_page and bd_page in register");
  if (!buf->bd_readers && !buf->bd_is_write)
    GPF_T1 ("must have write or read on the buffer for registration");
  rdbg_printf_2 (("  register itc=%x on L=%d \n", it, it->itc_page));
  itc->itc_is_registered = 1;
#if 1
  {
    it_cursor_t * ck = buf->bd_registered;
    while (ck)
      {
	if (itc == ck)
	  GPF_T1 ("double itc registration");
	ck = ck->itc_next_on_page;
      }
  }
#endif

  itc->itc_next_on_page = buf->bd_registered;
  buf->bd_registered = itc;
  itc->itc_buf_registered = buf;
}


void
itc_unregister_inner (it_cursor_t * itc, buffer_desc_t * buf, int is_transit)
{
  dk_mutex_t * ro_entered = NULL;
  it_cursor_t ** prev = &buf->bd_registered;
  it_cursor_t * reg, *fast;
  int ctr = 0;
  BUF_RO_REG_ENTER (itc, buf);
  fast = reg = buf->bd_registered;
  for (;;)
    {
      if (!reg)
	GPF_T1 ("cursor not registered on buffer in unregister");
      if (itc == reg)
	{
	  *prev = itc->itc_next_on_page;
	  itc->itc_next_on_page = NULL;
	  if (!is_transit)
	    itc->itc_is_registered = 0; /* when reg'd moves from page to page the flag stays set. Otherwise ureg at the same time can be confused */
	  itc->itc_buf_registered = NULL;
	  BUF_RO_REG_LEAVE (itc, buf);
	  return;
	}
      prev = &reg->itc_next_on_page;
      reg = reg->itc_next_on_page;
      if (!reg)
	GPF_T1 ("cursor not registered on buffer in unregister");
      if (fast && fast->itc_next_on_page)
	fast = fast->itc_next_on_page->itc_next_on_page;
      else
	fast = NULL;
      if (fast == reg) GPF_T1 ("cycle in registered cursors");
      ctr++;
    }
}


void
itc_unregister_inner_safe (it_cursor_t * itc, buffer_desc_t * buf, int is_transit)
{
  it_cursor_t ** prev = &buf->bd_registered;
  it_cursor_t * reg, *fast;
  fast = reg = buf->bd_registered;
  for (;;)
    {
      if (!reg)
	GPF_T1 ("cursor not registered on buffer in unregister");
      if (itc == reg)
	{
	  *prev = itc->itc_next_on_page;
	  itc->itc_next_on_page = NULL;
	  if (!is_transit)
	    itc->itc_is_registered = 0; /* when reg'd moves from page to page the flag stays set. Otherwise ureg at the same time can be confused */
	  itc->itc_buf_registered = NULL;
	  return;
	}
      prev = &reg->itc_next_on_page;
      reg = reg->itc_next_on_page;
      if (fast && fast->itc_next_on_page)
	fast = fast->itc_next_on_page->itc_next_on_page;
      else
	fast = NULL;
      if (!reg)
	GPF_T1 ("cursor not registered on buffer in unregister");
      if (fast == reg)
	GPF_T1 ("cycle in registered cursors");
    }
}


void
itc_unregister_n (buffer_desc_t * buf, id_hash_t * itcs)
{
  it_cursor_t ** prev = &buf->bd_registered;
  it_cursor_t * reg, *fast;
  fast = reg = buf->bd_registered;
  for (;;)
    {
      if (!reg)
	break;
      if (id_hash_get (itcs, (caddr_t)&reg))
	{
	  it_cursor_t * itc = reg;
	  *prev = reg->itc_next_on_page;
	  reg = reg->itc_next_on_page;
	  itc->itc_is_registered = 0;
	  itc->itc_next_on_page = NULL;
	  itc->itc_buf_registered = NULL;
	}
      else
	{
	  prev = &reg->itc_next_on_page;
	  reg = reg->itc_next_on_page;
	}
      if (!reg)
	break;
      if (fast && fast->itc_next_on_page)
	fast = fast->itc_next_on_page->itc_next_on_page;
      else
	fast = NULL;
      if (fast == reg)
	GPF_T1 ("cycle in registered cursors");
    }
}

void
itc_unregister (it_cursor_t * it_in)
{
  placeholder_t * itc = (placeholder_t *) it_in;
  buffer_desc_t * reg_buf;
  it_map_t * itm;
  dp_addr_t dp;
  if (itc->itc_bp.bp_transiting)
    goto enter;
  if (!itc->itc_is_registered)
    return;
  dp = itc->itc_page;
  itm = IT_DP_MAP (itc->itc_tree, dp);
  mutex_enter (&itm->itm_mtx);
  reg_buf = itc->itc_buf_registered;
  if (reg_buf && !reg_buf->bd_is_write && !reg_buf->bd_readers
      && dp == itc->itc_page && reg_buf->bd_page == dp)
    {
      itc_unregister_inner_safe ((it_cursor_t *) itc, reg_buf, 0);
      mutex_leave (&itm->itm_mtx);
      return;
    }

  mutex_leave (&itm->itm_mtx);
 enter:
  TC (tc_unregister_enter);
  {
    buffer_desc_t * buf;
    it_cursor_t itc_auto;
    it_cursor_t * reg_itc = &itc_auto;
    ITC_INIT (reg_itc, NULL, NULL);
    itc_from_it (reg_itc, itc->itc_tree);
    buf = itc_set_by_placeholder (reg_itc, itc);
    itc_unregister_inner ((it_cursor_t *)itc, buf, 0);
    itc_page_leave (reg_itc, buf);
  }
}


void
itc_unregister_while_on_page (it_cursor_t * it_in, it_cursor_t * preserve_itc, buffer_desc_t ** preserve_buf)
{
  placeholder_t * itc = (placeholder_t *) it_in;
  buffer_desc_t * reg_buf;
  it_map_t * itm;
  dp_addr_t dp;
  if (itc->itc_bp.bp_transiting)
    goto enter;
  if (!itc->itc_is_registered)
    return;
  dp = itc->itc_page;
  itm = IT_DP_MAP (itc->itc_tree, dp);
  mutex_enter (&itm->itm_mtx);
  reg_buf = itc->itc_buf_registered;
  if (reg_buf && !reg_buf->bd_is_write && !reg_buf->bd_readers
      && itc->itc_page == dp && reg_buf->bd_page ==dp)
    {
      itc_unregister_inner_safe ((it_cursor_t *) itc, reg_buf, 0);
      mutex_leave (&itm->itm_mtx);
      return;
    }

  mutex_leave (&itm->itm_mtx);
 enter:
  TC (tc_unregister_enter);
  {
    buffer_desc_t * buf;
    it_cursor_t itc_auto;
    it_cursor_t * reg_itc = &itc_auto;
    ITC_INIT (reg_itc, NULL, NULL);
    if (!preserve_itc->itc_fail_context) GPF_T1 ("must have fail ctx in itc_unregister_while_on_page ");
    itc_from_it (reg_itc, itc->itc_tree);
    itc_register (preserve_itc, *preserve_buf);
    page_leave_outside_map (*preserve_buf);
    ITC_FAIL (reg_itc)
      {
	buf = itc_set_by_placeholder (reg_itc, itc);
      }
    ITC_FAILED
      {
      }
    END_FAIL (reg_itc);
    itc_unregister_inner ((it_cursor_t *)itc, buf, 0);
    itc_page_leave (reg_itc, buf);
    *preserve_buf = page_reenter_excl (preserve_itc);
  }
}

void
isp_unregister_itc_list (void * dp, buffer_desc_t * buf)
{
  placeholder_t * first_itc = (placeholder_t *) buf->bd_registered;
  while (first_itc)
    {
      first_itc->itc_is_registered = 0;
      first_itc->itc_buf_registered = NULL;
      first_itc = (placeholder_t *) first_itc->itc_next_on_page;
    }
  buf->bd_registered = NULL;
}


void
it_unregister_all (index_tree_t * it)
{
  /* unregister all itc's. This is done when closing a transaction
     where there may be a result set of a cursor. */
  int inx;
  for (inx = 0; inx < IT_N_MAPS; inx++)
    {
      it_map_t * itm = &it->it_maps[inx];
      mutex_enter (&itm->itm_mtx);
      maphash ((maphash_func) isp_unregister_itc_list, &itm->itm_dp_to_buf);
      mutex_leave (&itm->itm_mtx);
    }
}



