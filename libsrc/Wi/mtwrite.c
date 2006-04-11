/*
 *  mtwrite.c
 *
 *  $Id$
 *
 *  Manages buffer rings and paging to disk.
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


#include "wi.h"
#include "list2.h"


int num_cont_pages=8;

#define IQ_NAME(iq) (iq->iq_id ? iq->iq_id : "io")

#if PAGE_TRACE
#define idbg_printf(q) printf q
#define rdbg_printf(q) printf q
#else
#define idbg_printf(q) 
#endif


int mti_writes_queued;
int mti_reads_queued;
int mt_write_pending = 0;


dk_set_t mti_io_queues;




io_queue_t *  bd_ioq;




io_queue_t *
db_io_queue (dbe_storage_t * dbs, dp_addr_t dp)
{
  if (dbs->dbs_disks)
    {
      OFF_T ign;
      disk_stripe_t * dst = dp_disk_locate (dbs, dp, &ign);
      return (dst->dst_iq);
    }
  else if (mti_io_queues)
    return ((io_queue_t *) mti_io_queues->data);
  return NULL;
}


#define BUF_SORT_DP(buf) (buf->bd_physical_page + buf->bd_storage->dbs_dp_sort_offset)


long tc_write_cancel;

void
buf_cancel_write (buffer_desc_t * buf)
{
  /* remove from write queue, mostly as a result of a dirty buffer going empty.
   * Note that the buf may simultaneously be cancelled on one thread and rem'd from write queue by the writer thread.
   * this is if the bufffer is occupied when the write turn comes, the write will be skipped and the buffer rem'd from the queue.
   * Thus the bd_iq of an occupied buffer can be async reset by another thread. */
  io_queue_t * iq = buf->bd_iq;
  if (!buf->bd_is_write)
    GPF_T1 ("write cancel when nobody inside buffer");
  if (buf->bd_in_write_queue
      && !buf->bd_iq)
    GPF_T1 ("buffer being queued for write during write cancel");
  if (iq)
    {
      IN_IOQ (iq);
      if (buf->bd_iq == iq)
	{
	  mti_writes_queued--;
	  rdbg_printf (("Write cancel L=%d P=%d \n", buf->bd_page, buf->bd_physical_page));
	  L2_DELETE (iq->iq_first, iq->iq_last, buf, bd_iq_);
	  TC (tc_write_cancel);
	  buf->bd_iq = NULL;
	  buf->bd_in_write_queue = 0;
	}
      LEAVE_IOQ (iq);
    }
}


void
iq_schedule (buffer_desc_t ** bufs, int n)
{
  int inx;
  int is_reads = 0;
  buf_sort (bufs, n, (sort_key_func_t) bd_phys_page_key);
  for (inx = 0; inx < n; inx++)
    {
      if (bufs[inx]->bd_iq)
	GPF_T1 ("buffer added to iq already has a bd_iq");
      bufs[inx]->bd_iq = db_io_queue (bufs[inx]->bd_storage, bufs[inx]->bd_physical_page);
    }
  DO_SET (io_queue_t *, iq, &mti_io_queues)
    {
      int n_added = 0;
      buffer_desc_t * ipoint;
      int was_empty;
      IN_IOQ (iq);
      inx = 0;
      ipoint  = iq->iq_first;
      was_empty = (iq->iq_first == NULL);

      while (inx < n)
	{
	  buffer_desc_t * buf = bufs[inx];
	  if (!buf || buf->bd_iq != iq)
	    {
	      inx++;
	      continue;
	    }
	  is_reads = buf->bd_being_read;
	  if (buf->bd_iq_next || buf->bd_iq_prev)
	    GPF_T1 ("can't schedule same buffer twice");
	  bufs[inx] = NULL;
	next_ipoint:
	  if (!ipoint)
	    {
	      L2_PUSH_LAST (iq->iq_first, iq->iq_last, buf, bd_iq_);
	      n_added++;
	      inx++;
	    }
	  else if (BUF_SORT_DP (ipoint) < BUF_SORT_DP (buf))
	    {
	      ipoint = ipoint->bd_iq_next;
	      goto next_ipoint;
	    }
	  else if (BUF_SORT_DP (ipoint) == BUF_SORT_DP (buf))
	    GPF_T1 ("the same buffer can't be scheduled twice for io");
	  else
	    {
	      L2_INSERT (iq->iq_first, iq->iq_last, ipoint, buf, bd_iq_);
	      n_added++;
	      inx++;
	    }
	  if (!buf->bd_being_read)
	    {
	      IN_PAGE_MAP (buf->bd_space->isp_tree);
	      page_leave_inner (buf);
	      LEAVE_PAGE_MAP (buf->bd_space->isp_tree);
	    }
	}
      LEAVE_IOQ (iq);
      if (n_added && !is_reads)
	idbg_printf (("IQ %s %d %s added, %s.\n", IQ_NAME (iq),
		      n_added, is_reads ? "reads" : "writes",
		      was_empty ? "starting" : "running"));
      if (n_added && was_empty)
	semaphore_leave (iq->iq_sem);

    }
  END_DO_SET ();
  if (n)
    {
      if (is_reads)
	mti_reads_queued += n;
      else
	mti_writes_queued += n;
    }
}


void
iq_clear (void)
{
  DO_SET (io_queue_t *, iq, &mti_io_queues)
    {
    }
  END_DO_SET();
}



int iq_on = 1;


void
iq_shutdown (int mode)
{
  int all_empty;
  if (IQ_STOP == mode)
    iq_on = 0;
  do
    {
      all_empty = 1;
      DO_SET (io_queue_t *, iq, &mti_io_queues)
	{
	  IN_IOQ (iq);
	  if (iq->iq_first)
	  {
	    du_thread_t * self = THREAD_CURRENT_THREAD;
	    all_empty = 0;
	    dk_set_push (&iq->iq_waiting_shut, (void*) self);
	    LEAVE_IOQ (iq);
	    rdbg_printf (("IQ shut wait start\n"));
	    semaphore_enter (self->thr_sem);
	    rdbg_printf (("IQ shut wait over\n"));
	  }
	  else
	  LEAVE_IOQ (iq);
	}
      END_DO_SET();
      if (mode == IQ_STOP && !all_empty)
	{
	  idbg_printf (("IQ shutdown re-check\n"));
	}
      if (IQ_SYNC == mode)
	break;
    }
  while (!all_empty);
  if (mode == IQ_STOP)
    {
      idbg_printf (("IQ shutdown confirmed\n"));
    }
}


void
iq_dry (io_queue_t * iq)
{
  /* the queue is empty. free whoever was waiting */
  DO_SET (du_thread_t *, w, &iq->iq_waiting_shut)
    {
      semaphore_leave (w->thr_sem);
    }
  END_DO_SET();
  dk_set_free (iq->iq_waiting_shut);
  iq->iq_waiting_shut = NULL;
}


void
iq_restart (void)
{
  iq_on = 1;
}


int
iq_is_on (void)
{
  return iq_on;
}


void
buf_release_read_waits (buffer_desc_t * buf, int to_reset)
{
  it_cursor_t * waiting;
  buf->bd_being_read = 0;
  waiting = buf->bd_waiting_read;
  if (RWG_WAIT_DECOY == to_reset)
    buf->bd_waiting_read = NULL;
  while (waiting)
    {
      it_cursor_t *next = waiting->itc_next_waiting;
      if (to_reset)
	waiting->itc_to_reset = to_reset;
      dbg_printf (("Release second read at %ld,\n", buf->bd_page));
      semaphore_leave (waiting->itc_thread->thr_sem);
      waiting = next;
    }
}


#define IQ_NO_OP 0
#define IQ_READ 1
#define IQ_WRITE 2

long tc_write_scrapped_buf;

void
iq_loop (io_queue_t * iq)
{
  index_tree_t * buf_it;
  index_space_t * buf_isp, * buf_new_isp;
  int leave_needed;
  long start_write_cum_time = 0;
  buffer_desc_t * buf;
  dp_addr_t dp_to;
  iq->iq_sem = THREAD_CURRENT_THREAD->thr_sem;

  IN_IOQ (iq);
  for (;;)
    {
      if (!iq->iq_current)
	iq->iq_current = iq->iq_first;

      if (!iq->iq_current)
	{
	  idbg_printf (("IQ %s dry\n", IQ_NAME (iq)));
	  iq_dry (iq);
	  LEAVE_IOQ (iq);
	  semaphore_enter (iq->iq_sem);
	  IN_IOQ (iq);
	  continue;
	}
      leave_needed = IQ_NO_OP;
      buf_it = NULL;
      buf = iq->iq_current;

      if (buf->bd_being_read)
	{
	  mti_reads_queued--;
	  if (!buf->bd_page)
	    GPF_T1 ("read ahead of 0");
	  LEAVE_IOQ (iq);
	  is_read_pending++;
	  buf_disk_read (buf);
	  is_read_pending--;
	  DBG_PT_READ (buf, ((lock_trx_t*) NULL));
	  leave_needed = IQ_READ;
	}
      else
	{
	  mti_writes_queued--;
	  LEAVE_IOQ (iq);
	  buf_isp = buf->bd_space;
	  if (buf_isp)
	    {
	      buf_it = buf_isp->isp_tree;
	      /* buffer replacement w/ write cancel can change the bd_space between
	       * reading the value and getting the mtx.  Possible bug of buffer repl during write also */
	      IN_PAGE_MAP (buf_it);
	      buf_new_isp = buf->bd_space;
	      if (buf->bd_is_dirty
		  && buf_new_isp && buf_it == buf_new_isp->isp_tree
		  && buf->bd_page
		  && !buf->bd_is_write
		  && !buf->bd_write_waiting)
		{
		  /* If the buffer hasn't moved out of sort order and
		     hasn't been flushed by a sync write */
		  buf->bd_readers++;
		  buf->bd_is_dirty = 0;
		  dp_to = buf->bd_physical_page;	/* dp may change once outside of map. */
		  /* clear dirty flag BEFORE write because the buffer
		   * can move and the flag can go back on DURING the write */
		  leave_needed = IQ_WRITE;
		  LEAVE_PAGE_MAP (buf_it);
		  buf_disk_write (buf, dp_to);

		  if (_thread_sched_preempt == 0 &&
		      write_cum_time - start_write_cum_time > 200)
		    {
		      start_write_cum_time = write_cum_time;
		      PROCESS_ALLOW_SCHEDULE ();
		    }


		}
	      else
		{
#ifdef O12DEBUG
		  dbg_printf (("[Canceled W %ld now %ld %ld]",
			       mtwrite_pages[n], buf->bd_page, buf->bd_physical_page));
		  rdbg_printf (("[Canceled W ??? now %ld %ld]",
				buf->bd_page, buf->bd_physical_page));
#endif
		  LEAVE_PAGE_MAP (buf_it);
		}
	    }
	  else
	    TC (tc_write_scrapped_buf);
	}
      IN_IOQ (iq);
      buf->bd_iq = NULL;
      buf->bd_in_write_queue = 0;
      iq->iq_current = buf->bd_iq_next;
      L2_DELETE (iq->iq_first, iq->iq_last, buf, bd_iq_);
      if (IQ_WRITE == leave_needed)
	{
	  LEAVE_IOQ (iq);
	  IN_PAGE_MAP (buf_it);
	  wi_inst.wi_n_dirty--;
	  page_leave_inner (buf);
	  LEAVE_PAGE_MAP (buf_it);
	  IN_IOQ (iq);
	}
      else if (IQ_READ == leave_needed)
	{
	  LEAVE_IOQ (iq);
	  IN_PAGE_MAP (buf->bd_space->isp_tree);
	  buf_release_read_waits (buf, RWG_WAIT_DECOY);
	  LEAVE_PAGE_MAP (buf->bd_space->isp_tree);
	  IN_IOQ (iq);
	}
    }
}


int
iq_mtx_entry_check (dk_mutex_t * mtx, du_thread_t * self, void * cd)
{
  it_not_in_any (self, NULL);
  return 1;
}


void
dst_assign_iq (disk_stripe_t * dst)
{
  if (dst)
    {
      DO_SET (io_queue_t *, iq, &mti_io_queues)
	{
	  if (box_equal (iq->iq_id, dst->dst_iq_id))
	    {
	      dst->dst_iq = iq;
	      return;
	    }
	}
      END_DO_SET();
    }
  if (!dst && mti_io_queues)
    return;
  {
    dk_thread_t * thr;
    NEW_VARZ (io_queue_t, iq);
    dk_set_push (&mti_io_queues, (void*) iq);
    iq->iq_id = (dst) ? box_copy (dst->dst_iq_id) : NULL;
    iq->iq_mtx = mutex_allocate ();
    mutex_option (iq->iq_mtx, (char *) (iq->iq_id ? iq->iq_id : "IQ"), iq_mtx_entry_check, (void *) iq);
    thr = PrpcThreadAllocate (
			      (thread_init_func) iq_loop, 50000, iq);
    if (!thr)
      {
	log_error ("Can's start the server because it can't create a system thread. Exiting");
        GPF_T;
      }
    iq->iq_sem = thr->dkt_process->thr_sem;
    semaphore_leave (thr->dkt_process->thr_sem);
    if (dst)
      dst->dst_iq = iq;
  }
}


void
mt_write_dirty (buffer_pool_t * bp, int age_limit, int phys_eq_log)
{
  /* Locate, sort and write dirty buffers. */
  buffer_desc_t **bufs, **local_bufs = NULL;
  buffer_desc_t *buf;
  int inx, fill = 0;
  size_t n;


  mt_write_pending = 1;
  bufs = bp->bp_sort_tmp;
  /* When using the preallocated bp_sort_tmp, set it to null and
   * put it back after the iq_schedule call. These are inside the bp_mtx.
   * If the bp_sort_temp is null when needing it,
   * just allocate one with dk_alloc and free it when done. */
  bp->bp_sort_tmp = NULL;
  if (!bufs)
    {
      n = sizeof (caddr_t) * (main_bufs / bp_n_bps);
      local_bufs = (buffer_desc_t **) dk_alloc (n);
      bufs = local_bufs;
    }
  ASSERT_IN_MTX (bp->bp_mtx);
  for (inx = 0; inx < bp->bp_n_bufs; inx++)
    {
      index_space_t * isp;
      buf = &bp->bp_bufs[inx];
      if (((int) (bp->bp_ts - buf->bd_timestamp)) < age_limit)
	continue;
      isp = buf->bd_space;
      if (isp && buf->bd_is_dirty)
	{
	  IN_PAGE_MAP (isp->isp_tree);
	  if (!buf->bd_is_write
	      && !buf->bd_readers
	      && !buf->bd_write_waiting
	      && !buf->bd_in_write_queue
	      && buf->bd_is_dirty
	      && buf->bd_space == isp /* could have been changed right before getting the page map*/
	      )
	    {
	      if (buf->bd_being_read)
		GPF_T1 ("planning write of buffer being read");
	      if (buf->bd_iq)
		GPF_T1 ("planning write of buffer with already with an iq");
	      buf->bd_in_write_queue = 1;
	      buf->bd_readers++;
	      bufs[fill++] = buf;
	    }
	  LEAVE_PAGE_MAP (isp->isp_tree);
	}
    }
  LEAVE_BP (bp);
  iq_schedule (bufs, fill);
  IN_BP (bp);
  if (!local_bufs)
    bp->bp_sort_tmp = bufs;
  else
    dk_free (local_bufs, n);
}


void
mt_write_start (int n_oldest)
{
  int inx;
  if (mt_write_pending
      || mti_writes_queued > 10
      || !iq_is_on ())
    return;
  DO_BOX (buffer_pool_t *, bp, inx, wi_inst.wi_bps)
    {
      IN_BP (bp);
      mt_write_dirty (bp, n_oldest, 0);
      LEAVE_BP (bp);
    }
  END_DO_BOX;
}


void
dbs_mtwrite_init (dbe_storage_t * dbs)
{
  if (dbs->dbs_disks)
    {

      DO_SET (disk_segment_t *, ds, &dbs->dbs_disks)
	{
	  int inx;
	  DO_BOX (disk_stripe_t *, dst, inx, ds->ds_stripes)
	    {
	      dst_assign_iq (dst);
	    }
	  END_DO_BOX;
	}
      END_DO_SET();
    }
  else
    {
      dst_assign_iq (NULL);
    }
}


void
mt_write_init ()
{
  DO_SET (wi_db_t *, wd, &wi_inst.wi_dbs)
    {
      DO_SET (dbe_storage_t *, dbs, &wd->wd_storage)
	{
	  dbs_mtwrite_init (dbs);
	}
      END_DO_SET ();
    }
  END_DO_SET();
  dbs_mtwrite_init (wi_inst.wi_temp);
}



