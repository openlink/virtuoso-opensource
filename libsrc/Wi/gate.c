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

#include "sqlnode.h"


long in_while_read;
long second_reads;
int is_read_pending;
int checkpoint_while_read = 0;
unsigned int bp_hit_ctr;


void
page_remove_read_wait (buffer_desc_t * buf, it_cursor_t * itc)
{
  it_cursor_t **prev = &buf->bd_waiting_read;
  GPF_T1 ("page_remove_read_wait is obsolete.");
  while (*prev)
    {
      if (*prev == itc)
	{
	  *prev = itc->itc_next_waiting;
	  return;
	}
      prev = &((*prev)->itc_next_waiting);
    }
  GPF_T1 ("cursor in 2nd read queue removed by other than itself");
}



int
itc_async_read_1 (it_cursor_t * itc, dp_addr_t dp, dp_addr_t phys_dp,
		  buffer_desc_t * buf, buffer_desc_t * decoy)
{
#if 0  
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


buffer_desc_t *
page_fault_map_sem (it_cursor_t * it, dp_addr_t dp, int stay_in_map)
{

/* ASSUMES IT'S INSIDE PAGE_MAP_SEM. ENTER_P CONTROLS WHETHER IT'S OK
   TO EXIT THE SEM. */

  buffer_desc_t decoy;
  buffer_desc_t *buf;
  index_space_t *isp_in;
  dp_addr_t phys_dp;
  ASSERT_IN_MAP (it->itc_tree);

  if (!dp)
    GPF_T1 ("Zero DP in page_fault_map_sem");
 retry_after_decoy:
  buf = isp_locate_page (it->itc_space, dp, &isp_in, &phys_dp);

  if (!buf)
    {
      if ((DP_DELETED == phys_dp || dbs_is_free_page (it->itc_tree->it_storage, phys_dp))
	  && !strchr (wi_inst.wi_open_mode, 'a'))
	{
	  log_error ("Reference to page with free remap dp = %ld, remap = %ld",
		     (long) phys_dp, (long) dp);
	  if (0 && DBS_PAGE_IN_RANGE (it->itc_tree->it_storage, phys_dp))
	    dbs_page_allocated (it->itc_space->isp_tree->it_storage, phys_dp);
	  else
	    return PF_OF_DELETED;
	}
      memset (&decoy, 0, sizeof (buffer_desc_t));
      decoy.bd_being_read = 1;

      sethash (DP_ADDR2VOID (dp), it->itc_space->isp_dp_to_buf, (void*)&decoy);
      ITC_LEAVE_MAP (it);
      buf = bp_get_buffer (NULL, BP_BUF_REQUIRED);
      if (itc_async_read_1 (it, dp, phys_dp, buf, &decoy))
	goto retry_after_decoy;

      is_read_pending++;
      buf->bd_being_read = 1;
      buf->bd_storage = it->itc_tree->it_storage;
      buf->bd_physical_page = phys_dp;
      BD_SET_IS_WRITE (buf, 0);
      buf->bd_write_waiting = NULL;
      it->itc_n_reads++;
      ITC_MARK_READ (it);
      buf->bd_space = isp_in;
      buf_disk_read (buf);
      buf->bd_space = NULL;
      is_read_pending--;
      ITC_IN_MAP (it);
      isp_set_buffer (isp_in, dp, phys_dp, buf);
      DBG_PT_READ (buf, it->itc_ltrx);
      buf->bd_being_read = 0;
      buf->bd_readers = 0;
      buf->bd_waiting_read = decoy.bd_waiting_read;
      buf_release_read_waits (buf, RWG_WAIT_DECOY);
    }
  else
    {
      if (buf->bd_being_read)
	{
	  if (stay_in_map)
	    {
	      checkpoint_while_read++;
	      buf_disk_read (buf);
	      return buf;
	    }
	  second_reads++;
	  it->itc_next_waiting = buf->bd_waiting_read;
	  buf->bd_waiting_read = it;
	  DBG_PT_PRINTF (("2nd in read for L=%d B=%p itc=%p \n", buf->bd_page, buf, it));
	  it->itc_to_reset = RWG_WAIT_DISK;
	  ITC_SEM_WAIT (it);
	  ITC_IN_MAP (it);
	  if (RWG_WAIT_DECOY == it->itc_to_reset)
	    {
	      TC (tc_read_wait_decoy);
	      /* it->itc_to_reset = RWG_WAIT_DISK;*/  /* mark it as disk wait which is less than split etc, not gt like rwg_wait_decoy */
	      goto retry_after_decoy;
	    }
	  GPF_T1 ("double read is supposed to go via the RWG_WAIT_DECOY route");
	  buf = isp_locate_page (it->itc_space, dp, &isp_in, &phys_dp);
	  /* the wait was on a decoy, which is now replaced by the actual buffer, so look that one up */
	  page_remove_read_wait (buf, it);
	  return buf;
	}
      else
	{
	  buf->bd_timestamp = buf->bd_pool->bp_ts;
	  if (bp_hit_ctr++ % 30 == 0)
	    buf->bd_pool->bp_ts++;
	  if (is_read_pending)
	    in_while_read++;
	}
    }
  return buf;
}


buffer_desc_t *
page_fault (it_cursor_t * it, dp_addr_t dp)
{
  return (page_fault_map_sem (it, dp, 0));
}


void
page_release_busted (buffer_desc_t * buf)
{
  it_cursor_t *waiting = buf->bd_to_bust;
  it_cursor_t *next;
  buf->bd_to_bust = NULL;
  while (waiting)
    {
      next = waiting->itc_next_waiting;
      waiting->itc_read_waits++;
      dbg_printf (("Release busted at %ld,\n", buf->bd_page));
      if (waiting->itc_to_reset <= waiting->itc_max_transit_change)
	buf->bd_readers++;
      else
	{
	  rdbg_printf (("pw reset itc %x chg %d max %d landed %d a for %ld itc_page %ld \n",
			waiting, (int) waiting->itc_to_reset,
			(int) waiting->itc_max_transit_change, (int)waiting->itc_landed,
			buf->bd_page, waiting->itc_page));
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
	  BD_SET_IS_WRITE (buf, 1);
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
	  buf->bd_write_waiting = next;
	  semaphore_leave (waiting->itc_thread->thr_sem);
	}
      waiting = next;
    }
  buf->bd_write_waiting = NULL;
  return W_NOT_RELEASED;
}



void
page_leave_inner (buffer_desc_t * buf)
{
  if (!is_crash_dump && buf->bd_space)
    ASSERT_IN_MAP (buf->bd_space->isp_tree);
  if (!buf->bd_page)
    buf->bd_space = NULL; /* if leaving del'd buffer, reset the space so reuse will not try to take the buffer out of the space's cache */
  if (buf->bd_readers)
    {
      buf->bd_readers--;
      if (buf->bd_readers < 0)
	GPF_T;			/* Negative readers */
      if (0 == buf->bd_readers)
	{
	  if (W_NOT_RELEASED == page_release_writes (buf))
	    page_release_busted (buf);
	}
    }
  else
    {
      if (!buf->bd_is_write)
	GPF_T1 ("Leaving a buffer with neither read or write access");
      BD_SET_IS_WRITE (buf, 0);
      if (W_NOT_RELEASED == page_release_writes (buf))
	page_release_busted (buf);
    }
}


void
itc_page_leave (it_cursor_t * it, buffer_desc_t * buf)
{
  ITC_IN_MAP (it);
  page_leave_inner (buf);
  ITC_LEAVE_MAP (it);
}


void
page_mark_change (buffer_desc_t * buf, int change)
{
  it_cursor_t *itc;
  if (!buf->bd_is_write)
    GPF_T;
  ASSERT_IN_MAP (buf->bd_space->isp_tree);
  for (itc = buf->bd_write_waiting; itc; itc = itc->itc_next_waiting)
    itc->itc_to_reset = MAX (itc->itc_to_reset, change);
  for (itc = buf->bd_to_bust; itc; itc = itc->itc_next_waiting)
    itc->itc_to_reset = MAX (itc->itc_to_reset, change);
  for (itc = buf->bd_waiting_read; itc; itc = itc->itc_next_waiting)
    itc->itc_to_reset = MAX (itc->itc_to_reset, change);
}


buffer_desc_t *
page_transit_if_can (it_cursor_t * itc, dp_addr_t dp, buffer_desc_t ** dest_ret,
		     buffer_desc_t ** buf_ret, int mode)
{
  buffer_desc_t *from = *buf_ret;
  buffer_desc_t *dest;
  ASSERT_IN_MAP (itc->itc_tree);
  itc->itc_to_reset = RWG_NO_WAIT;
  dest = page_fault_map_sem (itc, dp, 0);
  *dest_ret = dest;
  if (itc->itc_to_reset > RWG_NO_WAIT)
    return NULL;

  if (PA_READ == mode)
    {
      if (!dest->bd_is_write
	  && !dest->bd_write_waiting)
	{
	  dest->bd_readers++;
	  page_leave_inner (from);
	  *buf_ret = dest;
	  return dest;
	}
      return NULL;
    }
  else
    {
      if (!dest->bd_is_write
	  && 0 == dest->bd_readers)
	{
	  if (dest->bd_write_waiting || dest->bd_to_bust)
	    GPF_T1 ("nobody in yet there are cursor waiting at the gate");
	  BD_SET_IS_WRITE (dest, 1);
	  page_leave_inner (from);
	  *buf_ret = dest;
	  return dest;
	}
      return NULL;
    }
}


void
page_write_queue_add (buffer_desc_t * buf, it_cursor_t * itc)
{
  it_cursor_t **last = &buf->bd_write_waiting;
  TC (tc_write_wait);
  while (*last)
    last = &((*last)->itc_next_waiting);
  *last = itc;
  itc->itc_next_waiting = NULL;
}

void
page_read_queue_add (buffer_desc_t * buf, it_cursor_t * itc)
{
  TC (tc_read_wait);
  itc->itc_next_waiting = buf->bd_to_bust;
  buf->bd_to_bust = itc;
}


int
page_wait_access (it_cursor_t * itc, dp_addr_t dp_to, buffer_desc_t * buf_to,
		  buffer_desc_t * buf_from,
		  buffer_desc_t ** buf_ret, int mode, int max_change)
{
  itc->itc_to_reset = RWG_NO_WAIT;
  itc->itc_max_transit_change = max_change;
  if (!buf_to)
    {
      buf_to = page_fault_map_sem (itc, dp_to, 0);
      if (itc->itc_to_reset > itc->itc_max_transit_change)
	return itc->itc_to_reset;
    }
  if (PF_OF_DELETED == buf_to)
    {
      *buf_ret = PF_OF_DELETED;
      return 0;
    }
  if (PA_READ == mode)
    {
      if (!buf_to->bd_is_write
	  && !buf_to->bd_write_waiting)
	{
	  if (RWG_WAIT_NO_ENTRY == itc->itc_max_transit_change)
	    {
	      printf ("page_wait_access with RWG_WAIT_NO_ENTRY and no wait\n");
	      return RWG_WAIT_NO_ENTRY;
	    }
	  buf_to->bd_readers++;
	  if (buf_from)
	    page_leave_inner (buf_from);
	}
      else
	{
	  page_read_queue_add (buf_to, itc);
	  if (buf_from)
	    page_leave_inner (buf_from);
	  ITC_SEM_WAIT (itc);
	}
    }
  else
    {
      if (!buf_to->bd_is_write
	  && 0 == buf_to->bd_readers)
	{
	  if (RWG_WAIT_NO_ENTRY == itc->itc_max_transit_change)
	    {
	      printf ("page_wait_access with RWG_WAIT_NO_ENTRY and no wait\n");
	      return RWG_WAIT_NO_ENTRY;
	    }
	  if (buf_from)
	    page_leave_inner (buf_from);
	  BD_SET_IS_WRITE (buf_to, 1);
	}
      else
	{
	  page_write_queue_add (buf_to, itc);
	  if (buf_from)
	    page_leave_inner (buf_from);
	  ITC_SEM_WAIT (itc);
	}
    }
  if (itc->itc_to_reset <= max_change)
    {
#ifdef MTX_DEBUG
      if (PA_WRITE == mode)
	buf_to->bd_writer = THREAD_CURRENT_THREAD;
#endif
      *buf_ret = buf_to;
    }
  return (itc->itc_to_reset);
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
  buffer_desc_t *buf = *buf_ret;
  ITC_IN_MAP (itc);
  if (buf->bd_is_write)
    GPF_T1 ("Can't land while buffer being written");

  itc->itc_to_reset = RWG_NO_WAIT;
  if (buf->bd_readers > 1)
    {
      TC (tc_try_land_write);
      itc_register_cursor (itc, INSIDE_MAP);
      page_wait_access (itc, 0, *buf_ret, *buf_ret, buf_ret, PA_WRITE, RWG_WAIT_DATA);
      ITC_IN_MAP (itc);
      itc_unregister (itc, INSIDE_MAP);
      if (itc->itc_to_reset <= RWG_WAIT_DATA)
	{
	  itc->itc_landed = 1;
	}
    }
  else
    {
      buf->bd_readers = 0;
      BD_SET_IS_WRITE (buf, 1);
      itc->itc_landed = 1;
    }
  if (itc->itc_landed)
    {
      dbe_key_t *key = itc->itc_insert_key;
      ITC_FIND_PL (itc, buf);
      if (key)
	{
	  key->key_n_landings++;
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
  ITC_LEAVE_MAP (itc);
  return (itc->itc_to_reset);
}


buffer_desc_t *
page_reenter_excl (it_cursor_t * itc)
{
  buffer_desc_t *buf;
  if (!itc->itc_space_registered)
    GPF_T1 ("no reentry registration");
retry:

  ITC_IN_MAP (itc);
  page_wait_access (itc, itc->itc_page, NULL, NULL, &buf, PA_WRITE, RWG_WAIT_KEY);
  if (itc->itc_to_reset > RWG_WAIT_KEY)
    {
      TC (tc_reentry_split);
      goto retry;
    }
  ITC_IN_MAP (itc);
  itc_unregister (itc, INSIDE_MAP);
#if 1
  if (!itc->itc_tree->it_hi
      && itc->itc_position)
    {
      int inx;
      page_map_t *map = buf->bd_content_map;
      for (inx = 0; inx < map->pm_count; inx++)
	if (map->pm_entries[inx] == itc->itc_position)
	  {
	    itc->itc_map_pos = inx;
	    goto ok;
	  }
      GPF_T1 ("reentry to non-existent row");
    ok:;
    }
#endif


  ITC_FIND_PL (itc, buf);
  ITC_LEAVE_MAP (itc);
  /* the itc_page, itc_position are correct since it was registered */
  return buf;
}


void
itc_fix_back_link (it_cursor_t * itc, buffer_desc_t ** buf, dp_addr_t dp_from,
		   buffer_desc_t * old_buf, dp_addr_t back_link, int was_after_wait)
{
#ifndef NDEBUG
  dbg_page_map (old_buf);
  dbg_page_map (*buf);
#endif
  rdbg_printf ((
		"Bad parent link in %ld, coming from %ld, parent link = %ld.\n",
		(*buf)->bd_page, old_buf->bd_page, back_link));
  log_error ("Bad parent link in %ld, coming from %ld, parent link = %ld %s.",
	     (*buf)->bd_page, old_buf->bd_page, back_link,
	     was_after_wait ? "unconfirmed, detected after wait" : "confirmed");
  if (was_after_wait)
    return;
  if (correct_parent_links)
    {
      LONG_SET ((*buf)->bd_buffer + DP_PARENT, dp_from);
      (*buf)->bd_is_dirty = 1;
      log_info ("Bad parent link corrected");
    }
  else
    {
      log_error ("Consult your documentation on how to recover from "
		 "this situation");
      GPF_T1 ("fatal consistency check failure");
    }
}


void
itc_dive_transit (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t to)
{
  buffer_desc_t *old_buf = *buf_ret;
  buffer_desc_t *tmp;
  buffer_desc_t *dest_buf = NULL;
  dp_addr_t dp_from = itc->itc_page, back_link;

  itc->itc_parent_page = itc->itc_page;
  itc->itc_pos_on_parent = itc->itc_position;
  /* cache place, use when looking for next sibling */

  ITC_IN_MAP (itc);
  tmp = page_transit_if_can (itc, to, &dest_buf, buf_ret, PA_READ);
  ASSERT_IN_MAP (itc->itc_tree);
  if (!tmp)
    {
      if (itc->itc_to_reset >= RWG_WAIT_SPLIT)
	{
	  TC (tc_split_2nd_read);
	  page_leave_inner (*buf_ret);
	  *buf_ret = itc_reset (itc);
	  ITC_LEAVE_MAP (itc);
	  return;
	}
      itc->itc_read_waits += 256;
      page_wait_access (itc, to, dest_buf, *buf_ret, buf_ret, PA_READ, RWG_WAIT_KEY);
      if (itc->itc_to_reset >= RWG_WAIT_SPLIT)
	{
	  TC (tc_dive_split);
	  *buf_ret = itc_reset (itc);
	  ITC_LEAVE_MAP (itc);
	  return;
	}

    }
  else
    *buf_ret = tmp;
  back_link = LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT);
  ITC_LEAVE_MAP (itc);
  itc->itc_page = (*buf_ret)->bd_page;
  if (back_link != dp_from)
    itc_fix_back_link (itc, buf_ret, dp_from, old_buf, back_link, tmp == NULL);
  itc->itc_position = 0;
  if ((*buf_ret)->bd_readers <= 0
      || (*buf_ret)->bd_is_write)
    GPF_T1 ("dive transit ends in bd_readers <= 0 or is_write > 0");
}


void
itc_landed_down_transit (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t to)
{
  buffer_desc_t *old_buf = *buf_ret;
  buffer_desc_t *tmp;
  buffer_desc_t *dest_buf = NULL;
  dp_addr_t dp_from = itc->itc_page, back_link;

  itc->itc_parent_page = itc->itc_page;
  itc->itc_pos_on_parent = itc->itc_position;
  /* cache place, use when looking for next sibling */

  ITC_IN_MAP (itc);
  tmp = page_transit_if_can (itc, to, &dest_buf, buf_ret, PA_WRITE);
  if (!tmp)
    {
      if (itc->itc_desc_order)
	itc_skip_entry (itc, (*buf_ret)->bd_buffer);
      rdbg_printf (("landed down transit wait from %ld to %ld pos %d \n", (*buf_ret)->bd_page, dest_buf->bd_page, itc->itc_position));
      itc_register_cursor (itc, INSIDE_MAP);
      page_wait_access (itc, to, dest_buf, *buf_ret, buf_ret, PA_WRITE, RWG_WAIT_KEY);
      if (itc->itc_to_reset > RWG_WAIT_KEY)
	{
	  TC (tc_dtrans_split);

	  ITC_IN_MAP (itc);
	  *buf_ret = page_reenter_excl (itc);
	  ITC_IN_MAP (itc);
	  ITC_FIND_PL (itc, *buf_ret);
	  itc_unregister (itc, INSIDE_MAP);
	  if (itc->itc_is_on_row && itc->itc_desc_order)
	    itc_prev_entry (itc, *buf_ret);
	  return;
	}
      ITC_IN_MAP (itc);
      itc_unregister (itc, INSIDE_MAP);
    }
  else
    *buf_ret = tmp;
  itc->itc_page = (*buf_ret)->bd_page;
#ifdef NEW_HASH
  itc_hi_source_page_used (itc, itc->itc_page);
#endif

  ITC_FIND_PL (itc, *buf_ret);
  itc->itc_nth_seq_page++;
  back_link = LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT);
  if (back_link != dp_from)
    itc_fix_back_link (itc, buf_ret, dp_from, old_buf, back_link, tmp == NULL);
  ITC_LEAVE_MAP (itc);
  if (itc->itc_desc_order)
    {
      page_map_t *pm = (*buf_ret)->bd_content_map;
      itc->itc_position = pm->pm_entries[pm->pm_count - 1];
      itc->itc_map_pos = pm->pm_count - 1;
    }
  else
    itc->itc_position = SHORT_REF ((*buf_ret)->bd_buffer + DP_FIRST);
}

void
itc_down_transit (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t to)
{
  if (itc->itc_landed)
    itc_landed_down_transit (itc, buf_ret, to);
  else
    itc_dive_transit (itc, buf_ret, to);
}


void
itc_up_transit (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  int up_ctr = 0;
  buffer_desc_t *tmp;
  buffer_desc_t *dest_buf = NULL;
  dp_addr_t up;

up_again:
  ITC_IN_MAP (itc);
  up = LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT);

  tmp = page_transit_if_can (itc, up, &dest_buf, buf_ret, PA_WRITE);
  if (!tmp)
    {
      buffer_desc_t *not_entered = NULL;
      up_ctr ++;
      rdbg_printf (("up transit wait itc %x from %ld to %ld\n", itc, (*buf_ret)->bd_page, dest_buf->bd_page));
      TC (tc_up_transit_wait);
      page_wait_access (itc, up, dest_buf, NULL, &not_entered, PA_WRITE, RWG_WAIT_NO_ENTRY);
      goto up_again;
    }
  else
    *buf_ret = tmp;
  itc->itc_page = (*buf_ret)->bd_page;
#ifdef NEW_HASH
  itc_hi_source_page_used (itc, itc->itc_page);
#endif
  ITC_FIND_PL (itc, *buf_ret);
  ITC_LEAVE_MAP (itc);

  itc->itc_position = 0;
}




#define rdbg_printf_2(a)

void
itc_register_in_space (it_cursor_t * it, index_space_t * isp, int is_in_pmap)
{
  /* Called before going through hyperspace. If the gate busts you
     this will be the life line. */

  it_cursor_t *others_on_page;

  if (it->itc_space_registered)
    {
      GPF_T;			/* double registration */
      return;			/* Already registered. */
    }
  if (!is_in_pmap)
    IN_PAGE_MAP (isp->isp_tree);
  else
    ASSERT_IN_MAP (isp->isp_tree);

  rdbg_printf_2 (("  register itc=%x on L=%d \n", it, it->itc_page));
  it->itc_space_registered = isp;
  others_on_page = (it_cursor_t *) gethash (DP_ADDR2VOID (it->itc_page),
					    isp->isp_page_to_cursor);
#if 1
  {
    it_cursor_t * ck = others_on_page;
    while (ck)
      {
	if (it == ck)
	  GPF_T1 ("double itc registration");
	ck = ck->itc_next_on_page;
      }
  }
  #endif
  if (others_on_page)
    {
      /*
      itc_check_already_in (it, others_on_page);
      */
      it->itc_next_on_page = others_on_page->itc_next_on_page;
      others_on_page->itc_next_on_page = it;
    }
  else
    {
      sethash (DP_ADDR2VOID (it->itc_page),
	       isp->isp_page_to_cursor,
	       (void *) it);
      it->itc_next_on_page = NULL;
    }
  it->itc_space_registered = isp;
  if (!is_in_pmap)
    LEAVE_PAGE_MAP (isp->isp_tree);
}


void
itc_register_cursor (it_cursor_t * it, int is_in_pmap)
{
  itc_register_in_space (it, it->itc_space, is_in_pmap);
}


void
itc_register_lock_wait (it_cursor_t * it)
{
  itc_register_in_space (it, it->itc_tree->it_commit_space, INSIDE_MAP);
}

#if 1
static void
itc_check_loop_in_placeholder (placeholder_t * list)
{
  placeholder_t * pos = list;
  long loop = 0;
  while (pos)
    {
      pos = (placeholder_t *) pos->itc_next_on_page;
      if (loop++ > 10000)
	GPF_T1 ("Infinite loop detected in placeholder_t");
    }
}
#else
#define itc_check_loop_in_placeholder(list)
#endif

void
itc_unregister (it_cursor_t * it_in, int is_in_pmap)
{
  /* Called when leaving a page where there is a valid back position */
  dp_addr_t from;
  placeholder_t *it = (placeholder_t *) it_in;
  placeholder_t *positions;

  index_space_t *isp = it->itc_space_registered;
  if (!isp)
    return;

  if (!is_in_pmap)
    IN_PAGE_MAP (isp->isp_tree);
  else
    ASSERT_IN_MAP (isp->isp_tree);

  rdbg_printf_2 (("  unregister itc=%x L=%d  \n", it, it->itc_page));
  from = it->itc_page;
  it->itc_space_registered = NULL;
  positions = (placeholder_t *)
    gethash (DP_ADDR2VOID (from), isp->isp_page_to_cursor);
  if (positions)
    {
      if (positions == it)
	{
	  if (positions->itc_next_on_page)
	    {
	      sethash (DP_ADDR2VOID (from), isp->isp_page_to_cursor,
		       it->itc_next_on_page);
	    }
	  else
	    {
	      remhash (DP_ADDR2VOID (from), isp->isp_page_to_cursor);
	    }
	}
      else
	{
	  placeholder_t *prev = positions;
	  placeholder_t *pos = (placeholder_t *) positions->itc_next_on_page;
	  itc_check_loop_in_placeholder (pos);
	  while (pos)
	    {
	      if (pos == it)
		{
		  prev->itc_next_on_page = pos->itc_next_on_page;
		  goto end;
		}
	      prev = pos;
	      pos = (placeholder_t *) pos->itc_next_on_page;
	    }
	  /* GPF_T; Unregister cursor not found */
	}
    }
end:
  it->itc_next_on_page = NULL;
  it->itc_space_registered = NULL;
  if (!is_in_pmap)
    LEAVE_PAGE_MAP (isp->isp_tree);
}


void
isp_unregister_itc_list (dp_addr_t dp, placeholder_t * first_itc)
{
  while (first_itc)
    {
      first_itc->itc_space_registered = NULL;
      first_itc = (placeholder_t *) first_itc->itc_next_on_page;
    }
}


void
isp_unregister_all (index_space_t * isp)
{
  /* unregister all itc's. This is done when closing a transaction
     where there may be a result set of a cursor. */
  ASSERT_IN_MAP (isp->isp_tree);
  maphash ((maphash_func) isp_unregister_itc_list, isp->isp_page_to_cursor);
}



