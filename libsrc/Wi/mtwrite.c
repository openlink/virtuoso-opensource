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
#include "list2.h"


int num_cont_pages=8;

#define IQ_NAME(iq) (iq->iq_id ? iq->iq_id : "io")

#if 0 /*PAGE_TRACE*/
#define idbg_printf(q) printf q
#undef rdbg_printf
#define rdbg_printf(q) printf q
#else
#define idbg_printf(q)
#endif


int mti_writes_queued;
int mti_reads_queued;
#if defined (MTX_DEBUG) && defined (IQ_TRACE)
#define IQ_ENTER_TRACE(buf, iq) buf->bd_enter_line = buf->bd_read_waiting ? - __LINE__ : __LINE__
#define IQ_LEAVE_TRACE(buf) buf->bd_leave_line = buf->bd_read_waiting ? - __LINE__ : __LINE__
#else
#define IQ_ENTER_TRACE(buf, iq)
#define IQ_LEAVE_TRACE(buf)
#endif

dk_set_t mti_io_queues;
int n_iqs; /*length of mti_io_queues*/

#define BD_SYNC ((db_buf_t)1)


io_queue_t *  bd_ioq;




io_queue_t *
db_io_queue (dbe_storage_t * dbs, dp_addr_t dp)
{
  if (dbs->dbs_disks)
    {
      OFF_T ign;
      disk_stripe_t * dst = dp_disk_locate (dbs, dp, &ign, 0, NULL);
      return (dst->dst_iq);
    }
  else if (mti_io_queues)
    return ((io_queue_t *) mti_io_queues->data);
  return NULL;
}


#define BUF_SORT_DP(buf) (buf->bd_physical_page + buf->bd_storage->dbs_dp_sort_offset)


long tc_write_cancel;
long tc_merge_reads;
long tc_merge_read_pages;

void
buf_cancel_write (buffer_desc_t * buf)
{
  /* remove from write queue, mostly as a result of a dirty buffer going empty.
   * Note that the buf may simultaneously be cancelled on one thread and rem'd from write queue by the writer thread.
   * this is if the buffer is occupied when the write turn comes, the write will be skipped and the buffer rem'd from the queue.
   * Thus the bd_iq of an occupied buffer can be async reset by another thread. */
  io_queue_t * iq = buf->bd_iq;
  if (buf->bd_tree)
      ASSERT_OUTSIDE_MAP (buf->bd_tree, buf->bd_page);

  /* Note that this can block waiting for IQ which is owned by another
  thread in iq_schedule. The thread in iq_schedule can block on this
  same page map when leaving the buffer after queue insertion, hence
  deadlocking.  Hence this function's caller is required to own the
  buffer but not to be in its tree's map when calling. */

  if (!buf->bd_is_write)
    GPF_T1 ("write cancel when nobody inside buffer");
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
	}
      LEAVE_IOQ (iq);
    }
}

extern int dbf_fast_cpt;



void
iq_sync_disks (io_queue_t * iq)
{
#ifdef HAVE_FSYNC
  dbe_storage_t * dbs = wi_inst.wi_master;
  int inx;
  if (dbf_fast_cpt)
    return;
  switch (c_checkpoint_sync)
    {
    case 0:
	/* NO SYNC */
	break;

    case 1:
#ifndef WIN32
      sync();
#endif
      break;

    case 2:
    default:
      if (dbs->dbs_disks)
	{
	  DO_SET (disk_segment_t *, seg, &dbs->dbs_disks)
	    {
	      DO_BOX (disk_stripe_t *, dst, inx, seg->ds_stripes)
		{
		  if (iq != dst->dst_iq)
		    continue;
		  fd_fsync (dst->dst_fds[0]);
		}
	      END_DO_BOX;
	    }
	  END_DO_SET ();
	}
      else
	{
	  fd_fsync (dbs->dbs_fd);
	}
    }
#endif
}


dp_addr_t 
buf_nn_phys_dp (buffer_desc_t * buf)
{
  if (!buf)
    return DP_MAX;
  return buf->bd_physical_page;
}


dp_addr_t
iq_schedule (buffer_desc_t ** bufs, int n)
{
  dp_addr_t max_dp = 0;
  int inx;
  int is_reads = 0;
  buf_sort (bufs, n, (sort_key_func_t)buf_nn_phys_dp );
  for (inx = 0; inx < n; inx++)
    {
      if (!bufs[inx])
	continue;
      if (BD_SYNC == bufs[inx]->bd_buffer)
	continue;
      if (bufs[inx]->bd_physical_page > max_dp)
	max_dp = bufs[inx]->bd_physical_page;
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
	      IQ_ENTER_TRACE (buf, iq);
	      n_added++;
	      inx++;
	    }
	  else if (BUF_SORT_DP (ipoint) < BUF_SORT_DP (buf))
	    {
	      ipoint = ipoint->bd_iq_next;
	      goto next_ipoint;
	    }
	  else if (ipoint->bd_physical_page == buf->bd_physical_page && ipoint->bd_storage == buf->bd_storage) /* do the assert check without the sort offset.  Can be the sort offset changes on another thread due to dbs size changes so can have a false hit */
	    GPF_T1 ("the same buffer can't be scheduled twice for io");
	  else
	    {
	      L2_INSERT (iq->iq_first, iq->iq_last, ipoint, buf, bd_iq_);
	      IQ_ENTER_TRACE (buf, iq);
	      n_added++;
	      inx++;
	    }
	  if (!buf->bd_being_read && BD_SYNC != buf->bd_buffer)
	    {
	      page_leave_outside_map (buf);
	    }
	}
      LEAVE_IOQ (iq);
      if (n_added && !is_reads)
	{
	  iq->iq_n_writes += n_added;
	  idbg_printf (("IQ %s %d %s added, %s.\n", IQ_NAME (iq),
			n_added, is_reads ? "reads" : "writes",
			was_empty ? "starting" : "running"));
	}
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
  return max_dp;
}


long tc_write_scrapped_buf;

extern int c_use_aio;
long tc_aio_seq_read;
long tc_aio_seq_write;

#define AIO_NONE 0
#define AIO_NATIVE 1
#define AIO_MERGING 2

#ifdef HAVE_AIO

#include <aio.h>

#define IQ_LISTIO

#define MAX_MERGE 128
#define MERGE_THR_SIZE ((30*1024)+(MAX_MERGE*PAGE_SZ))

int lio_max_gap = 10;

#if defined (linux) && defined (__GNUC__)
void
iq_read_merge (struct aiocb ** list, int n, char * temp)
{
  int inx, inx2, bytes;
  int fd = list[0]->aio_fildes;
  OFF_T first_offset = list[0]->aio_offset;
  OFF_T last_planned = first_offset, seek;
  for (inx = 1; inx < n; inx++)
    {
      if (list[inx]->aio_fildes != fd
	  || list[inx]->aio_lio_opcode != LIO_READ)
	break;
      if (list[inx]->aio_offset - last_planned > lio_max_gap * PAGE_SZ
	  || list[inx]->aio_offset - first_offset > (MAX_MERGE - 1) * PAGE_SZ)
	break;
      list[inx]->__error_code = -1;
      last_planned = list[inx]->aio_offset;
    }
  seek = LSEEK (fd, first_offset, SEEK_SET);
  if (seek != first_offset)
    GPF_T1 ("bad return from lseek");
  if (first_offset == last_planned)
    {
      bytes = read (fd, list[0]->aio_buf, PAGE_SZ);
      if (bytes != PAGE_SZ)
	GPF_T1 ("bad no of bytes from read");
      list[0]->__return_value = bytes;
      list[0]->__error_code = 0;
      return;
    }
  list[0]->__error_code = -1;
  tc_merge_reads++;
  tc_merge_read_pages += ((last_planned - first_offset) + PAGE_SZ) / PAGE_SZ;
  bytes = read (fd, temp,  (last_planned - first_offset) + PAGE_SZ);
  if (bytes != (last_planned - first_offset) + PAGE_SZ)
    GPF_T1 ("bad no of bytes returned for merged read");
  for (inx2 = 0; inx2 <= MIN (inx, n - 1); inx2++)
    {
      if (-1 == list[inx2]->__error_code)
	{
	  memcpy_16 (list[inx2]->aio_buf, temp + (list[inx2]->aio_offset - first_offset), PAGE_SZ);
	  list[inx2]->__return_value = PAGE_SZ;
	  list[inx2]->__error_code = 0;
	}
    }
}


void
iq_write_merge (struct aiocb ** list, int n, char * temp)
{
  int inx, inx2, bytes;
  int fd = list[0]->aio_fildes;
  OFF_T first_offset = list[0]->aio_offset;
  OFF_T last_planned = first_offset, seek;
  for (inx = 1; inx < n; inx++)
    {
      if (list[inx]->aio_fildes != fd
	  || list[inx]->aio_lio_opcode != LIO_WRITE)
	break;
      if (list[inx]->aio_offset - last_planned != PAGE_SZ
	  || list[inx]->aio_offset - first_offset > (MAX_MERGE - 1) * PAGE_SZ)
	break;
      list[inx]->__error_code = -1;
      last_planned = list[inx]->aio_offset;
    }
  seek = LSEEK (fd, first_offset, SEEK_SET);
  if (seek != first_offset)
    GPF_T1 ("bad return from lseek");
  if (first_offset == last_planned)
    {
      bytes = write (fd, list[0]->aio_buf, PAGE_SZ);
      if (bytes != PAGE_SZ)
	GPF_T1 ("bad no of bytes from read");
      list[0]->__return_value = bytes;
      list[0]->__error_code = 0;
      return;
    }
  list[0]->__error_code = -1;
  for (inx2 = 0; inx2 <= MIN (inx, n - 1); inx2++)
    {
      if (-1 == list[inx2]->__error_code)
	{
	  memcpy (temp + (list[inx2]->aio_offset - first_offset), list[inx2]->aio_buf, PAGE_SZ);
	  list[inx2]->__return_value = PAGE_SZ;
	  list[inx2]->__error_code = 0;
	}
    }
  bytes = write (fd, temp,  (last_planned - first_offset) + PAGE_SZ);
  if (bytes != (last_planned - first_offset) + PAGE_SZ)
    GPF_T1 ("bad no of bytes returned for merged read");
}


void
iq_listio (struct aiocb ** list, int fill)
{
  /* like lio_listio with LIO_WAIT , but merges reads that are close enough together, only PAGE_SZ chunks donw  */
  char temp_space [(MAX_MERGE + 1) * PAGE_SZ];
  char * temp = ALIGN_8K (&temp_space[0]);
  int inx;
  for (inx = 0; inx < fill; inx++)
    {
      if (list[inx]->__return_value)
	continue;
      if (LIO_READ == list[inx]->aio_lio_opcode)
	iq_read_merge (&list[inx], fill - inx, temp);
      else
		iq_write_merge (&list[inx], fill - inx, temp);
    }
}
#endif


int
aio_fd (buffer_desc_t * buf, dk_hash_t * aio_ht, OFF_T * off)
{
  dbe_storage_t * dbs = buf->bd_storage;
  dk_hash_t * dbs_ht = (dk_hash_t *) gethash ((void*) buf->bd_storage, aio_ht);
  if (buf->bd_storage->dbs_disks)
    {
      int fd;
      disk_stripe_t * dst;
      if (!dbs_ht)
	{
	  dbs_ht = hash_table_allocate (10);
	  sethash ((void*)dbs, aio_ht, (void*) dbs_ht);
	}
      dst = dp_disk_locate (buf->bd_storage, buf->bd_physical_page, off, 1, NULL);
      fd = (int)(ptrlong) gethash ((void*)dst, dbs_ht);
      if (!fd)
	{
	  fd = dst_fd (dst);
	  sethash ((void*)dst, dbs_ht, (void*)(ptrlong)fd);
	}
      return fd;
    }
  else
    {
      if (!dbs_ht)
	{
	  sethash ((void*)buf->bd_storage, aio_ht, (void*) 1);
	  mutex_enter (buf->bd_storage->dbs_file_mtx);
	}
      *off = ((int64)PAGE_SZ) * buf->bd_physical_page;
      return buf->bd_storage->dbs_fd;
    }
}


void
aio_fd_free (dk_hash_t * aio_ht)
{
  DO_HT (dbe_storage_t *, dbs, dk_hash_t *, ht, aio_ht)
    {
      if ((dk_hash_t*) 1 == ht)
	{
	  mutex_leave (dbs->dbs_file_mtx);
	}
      else
	{
	  DO_HT (disk_stripe_t *, dst, ptrlong, fd, ht)
	    {
	      dst_fd_done (dst, fd, NULL);
	    }
	  END_DO_HT;
	  hash_table_free (ht);
	}
    }
  END_DO_HT;
  hash_table_free (aio_ht);
}


#define MAX_AIO_BATCH 200

extern long read_cum_time;
extern long disk_reads;
extern long disk_writes;


void
iq_aio (io_queue_t * iq)
{
  /* runs a batch through aio. Enters and returns inside iq_mtx */
  struct aiocb cb[MAX_AIO_BATCH];
  struct aiocb * list[MAX_AIO_BATCH];
  buffer_desc_t * bufs[MAX_AIO_BATCH];
  int32 lio_time, n_reads = 0, n_writes = 0;
  int fill = 0, inx, rc;
  dp_addr_t last_read = 0, last_write = 0;
  dk_hash_t * aio_ht = hash_table_allocate (10);
  for (;;)
    {
      it_map_t * buf_itm = NULL;
      OFF_T off;
      buffer_desc_t * buf;
      if (!iq->iq_current)
	iq->iq_current = iq->iq_first;
      if (!iq->iq_current || BD_SYNC == iq->iq_current->bd_buffer)
	{
	  if (!fill)
	    return;
	  else
	    break;
	}
      buf = iq->iq_current;
      if (buf->bd_being_read)
	{
	  int fd = aio_fd (buf, aio_ht, &off);

	  if (!buf->bd_is_write) GPF_T1 ("read ahead buf must have  bd_is_write");
	  mti_reads_queued--;
	  if (!buf->bd_page)
	    GPF_T1 ("read ahead of 0");
	  n_reads++;
	  iq->iq_action_ctr += 2; /* counts for 3 if syncing for cpt */
	  memset (&cb[fill], 0, sizeof (struct aiocb));
	  cb[fill].aio_fildes = fd;
	  cb[fill].aio_offset = off;
	  cb[fill].aio_lio_opcode = LIO_READ;
	  cb[fill].aio_buf = buf->bd_buffer;
	  cb[fill].aio_nbytes = PAGE_SZ;
	  list[fill] = &cb[fill];
	  bufs[fill] = buf;
	  last_write = 0;
	  if (last_read + PAGE_SZ == off)
	    tc_aio_seq_read++;
	  last_read = off;
	  fill++;
	}
      else
	{
	  mti_writes_queued--;
	  LEAVE_IOQ (iq);
	  if (bp_buf_enter (buf, &buf_itm))
	    {
	      /* now we are in the mtx of buf_itm and the buf was not reused while waiting for the mtx */
	      it_map_t * buf_itm = IT_DP_MAP (buf->bd_tree, buf->bd_page);
	      if (buf->bd_is_dirty
		  && buf->bd_tree
		  && buf->bd_page
		  && !buf->bd_is_write
		  && !buf->bd_write_waiting)
		{
		  /* If the buffer hasn't moved out of sort order and
		     hasn't been flushed by a sync write */
		  buf->bd_readers++;
		  buf->bd_is_dirty = 0;
		  /* clear dirty flag BEFORE write because the buffer
		   * can move and the flag can go back on DURING the write */
		  mutex_leave (&buf_itm->itm_mtx);
		  {
		    OFF_T off;
		    int fd = aio_fd (buf, aio_ht, &off);
		    if (!buf->bd_page)
		      GPF_T1 ("read ahead of 0");
		    iq->iq_action_ctr += 1; /* counts for 3 if syncing for cpt */
		    n_writes++;
		    memset (&cb[fill], 0, sizeof (struct aiocb));
		    cb[fill].aio_fildes = fd;
		    cb[fill].aio_offset = off;
		    cb[fill].aio_lio_opcode = LIO_WRITE;
		    cb[fill].aio_buf = buf->bd_buffer;
		    cb[fill].aio_nbytes = PAGE_SZ;
		    list[fill] = &cb[fill];
		    bufs[fill] = buf;
		    last_read = 0;
		    if (last_write + PAGE_SZ == off)
	    tc_aio_seq_write++;
		    last_write = off;
		    fill++;
		  }
		}
	      else
		{
		  mutex_leave (&buf_itm->itm_mtx);
		}
	    }
	  else
	    TC (tc_write_scrapped_buf);
	  IN_IOQ (iq);
	}
      buf->bd_iq = NULL;
      iq->iq_current = buf->bd_iq_next;
      L2_DELETE (iq->iq_first, iq->iq_last, buf, bd_iq_);
      if (MAX_AIO_BATCH == fill || !iq->iq_current)
	break;
    }
  LEAVE_IOQ (iq);
  lio_time = get_msec_real_time ();
#if defined (linux) && defined (__GNUC__)
  if (AIO_MERGING == c_use_aio)
    iq_listio (list, fill);
  else
#endif
    {
      rc = lio_listio (LIO_NOWAIT, list, fill, NULL);
      if (rc)
	{
	  log_error ("lio_listion returns %d errno %d", rc, errno);
	  GPF_T1 ("error in lio_listio");
	}
    }
  for (inx = 0; inx < fill; inx++)
    {
      buffer_desc_t * buf = bufs[inx];
      it_map_t * itm = IT_DP_MAP (buf->bd_tree, buf->bd_page);
      if (AIO_NATIVE == c_use_aio)
	{
	  rc = aio_suspend (&list[inx], 1, NULL);
	  if (rc) GPF_T1 ("aio_suspend returns error");
	  /*printf ("aio done %d\n", buf->bd_physical_page);*/
	}
#if defined (linux) && defined (__GNUC__)
      if (cb[inx].__return_value != PAGE_SZ || cb[inx].__error_code)
	GPF_T1 ("aio cb has error code");
#endif
      if (buf->bd_being_read)
	{
	  int flags = SHORT_REF (buf->bd_buffer + DP_FLAGS);
	  if (DPF_INDEX == flags)
	    pg_make_map (buf);
	  else if (DPF_COLUMN == flags)
	    pg_make_col_map (buf);
	  else if (buf->bd_content_map)
	    {
	      resource_store (PM_RC (buf->bd_content_map->pm_size), (void*) buf->bd_content_map);
	      buf->bd_content_map = NULL;
	    }
	  if (DPF_BLOB == flags || DPF_BLOB_DIR == flags)
	    TC(tc_blob_read);

	}
      mutex_enter (&itm->itm_mtx);
      if (buf->bd_being_read)
	{
	  buf->bd_pl = IT_DP_PL (buf->bd_tree, buf->bd_page);
	  buf->bd_being_read = 0;
	  buf->bd_batch_id = 0;
	}
      else
	{
	  mtx_assert (buf->bd_pl == IT_DP_PL (buf->bd_tree, buf->bd_page));
	  wi_inst.wi_n_dirty--;
	}
      page_leave_inner (buf);
      mutex_leave (&itm->itm_mtx);
    }
  lio_time = get_msec_real_time () - lio_time;
  read_cum_time += (lio_time / fill) * n_reads;
  write_cum_time += (lio_time / fill) * n_writes;
  disk_writes += n_writes;
  disk_reads += n_reads;
  aio_fd_free (aio_ht);
  IN_IOQ (iq);
}
#else
#define MERGE_THR_SIZE 50000
#endif


void
iq_clear (void)
{
  DO_SET (io_queue_t *, iq, &mti_io_queues)
    {
    }
  END_DO_SET();
}



int iq_on = 1;
int enable_mt_sync = 1;


void
iq_shutdown (int mode)
{
  int all_empty, inx;
  int n_iq = dk_set_length (mti_io_queues);
  static buffer_desc_t * sync_bufs;
  if (!sync_bufs || box_length (sync_bufs) < sizeof (buffer_desc_t) * n_iq)
    {
      int inx = 0;
      if (sync_bufs)
	dk_free_box ((caddr_t)sync_bufs);
      sync_bufs = (buffer_desc_t*)dk_alloc_box (sizeof (buffer_desc_t) * n_iq, DV_BIN);
      memset (sync_bufs, 0, n_iq * sizeof (buffer_desc_t));
      DO_SET (io_queue_t *, iq, &mti_io_queues)
	{
	  sync_bufs[inx].bd_buffer = BD_SYNC;
	  sync_bufs[inx].bd_storage = wi_inst.wi_master;
	  sync_bufs[inx].bd_page = 0xffffffff;
	  sync_bufs[inx].bd_iq = iq;
	  inx++;
	}
      END_DO_SET();
    }
  if (enable_mt_sync)
    {
      for (inx  = 0; inx < n_iq; inx++)
	{
	  if (!sync_bufs[inx].bd_batch_id)
	    {
	      buffer_desc_t * tmp = &sync_bufs[inx];
	      sync_bufs[inx].bd_batch_id = 1;
	      iq_schedule (&tmp, 1);
	    }
	}
    }
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
	    iq->iq_action_ctr = 0;
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


#define IQ_NO_OP 0
#define IQ_READ 1
#define IQ_WRITE 2


void
iq_loop (io_queue_t * iq)
{
  it_map_t * buf_itm;
  int leave_needed;
  long start_write_cum_time = 0;
  buffer_desc_t * buf;
  dp_addr_t dp_to;
  iq->iq_sem = THREAD_CURRENT_THREAD->thr_sem;

  IN_IOQ (iq);
  for (;;)
    {
      iq->iq_action_ctr++;
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
      if (iq->iq_waiting_shut && iq_on && iq->iq_action_ctr > main_bufs / (n_iqs * n_iqs)
	  && !wi_inst.wi_checkpoint_atomic)
	{
	  /* if the  iq's are not being turned off and the iq has not gone empty within main_bufs operations, then it can be the iq will not go empty and cpt will be indefinitely delayed.  So let the cpt thread continue.  It will eventually stop all processing and turn off the iq's after activity is suspended.
	  * n_iqs is squared because cpt  waits on each in turn.  In this way the max cpt wait is about the time it takes for the combined iq's to turn over the buffer pool worth of data.
	  * LOOK OUT.  Inside atomic checkpoint waiting for sync must be strict. During unremap Sync means all iq's empty  Else meltdown fuckup. If sync not strict, buffers get scrapped before written */
	  iq_dry (iq);
	}
      buf = iq->iq_current;
#ifdef HAVE_AIO
      if (AIO_NONE != c_use_aio && BD_SYNC != buf->bd_buffer)
	{
	  iq_aio (iq);
	  continue;
	}
#endif
      leave_needed = IQ_NO_OP;
      buf_itm = NULL;

      if (BD_SYNC == buf->bd_buffer)
	{
	  LEAVE_IOQ (iq);
	  iq_sync_disks (iq);
	}
      else if (buf->bd_being_read)
	{
	  if (!buf->bd_is_write) GPF_T1 ("read ahead buf must have  bd_is_write");
	  mti_reads_queued--;
	  if (!buf->bd_page)
	    GPF_T1 ("read ahead of 0");
	  iq->iq_action_ctr += 2; /* counts for 3 if syncing for cpt */
	  LEAVE_IOQ (iq);
	  is_read_pending++;
	  BUF_PW (buf);
	  buf_disk_read (buf);
	  is_read_pending--;
	  DBG_PT_READ (buf, ((lock_trx_t*) NULL));
	  leave_needed = IQ_WRITE;
	  buf_itm = IT_DP_MAP (buf->bd_tree, buf->bd_page);
	}
      else
	{
	  mti_writes_queued--;
	  LEAVE_IOQ (iq);

	  if (bp_buf_enter (buf, &buf_itm))
	    {
	      /* now we are in the mtx of buf_itm and the buf was not reused while waiting for the mtx */
	      if (buf->bd_is_dirty
		  && buf->bd_tree
		  && buf->bd_page
		  && !buf->bd_readers && !buf->bd_is_write
		  && !buf->bd_write_waiting)
		{
		  /* If the buffer hasn't moved out of sort order and
		     hasn't been flushed by a sync write */
		  BD_SET_IS_WRITE (buf, 1);
		  buf->bd_is_dirty = 0;
		  dp_to = buf->bd_physical_page;	/* dp may change once outside of map. */
		  /* clear dirty flag BEFORE write because the buffer
		   * can move and the flag can go back on DURING the write */
		  leave_needed = IQ_WRITE;
		  mutex_leave (&buf_itm->itm_mtx);
		  buf_disk_write (buf, dp_to);
		  dp_may_compact (buf->bd_storage, buf->bd_page);
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
		  dbg_printf (("[Cancelled W %ld now %ld %ld]",
			       mtwrite_pages[n], buf->bd_page, buf->bd_physical_page));
		  rdbg_printf (("[Cancelled W ??? now %ld %ld]",
				buf->bd_page, buf->bd_physical_page));
#endif
		  mutex_leave (&buf_itm->itm_mtx);
		}
	    }
	  else
	    TC (tc_write_scrapped_buf);
	}
      IN_IOQ (iq);
      buf->bd_iq = NULL;
      iq->iq_current = buf->bd_iq_next;
      L2_DELETE (iq->iq_first, iq->iq_last, buf, bd_iq_);
      buf->bd_batch_id = 0;
      if (IQ_WRITE == leave_needed)
	{
	  it_map_t * itm = IT_DP_MAP (buf->bd_tree, buf->bd_page);
	  LEAVE_IOQ (iq);
	  mutex_enter (&itm->itm_mtx);
	  if (buf->bd_being_read)
	    {
	      buf->bd_pl = IT_DP_PL (buf->bd_tree, buf->bd_page);
	      buf->bd_being_read = 0;
	      buf->bd_batch_id = 0;
	}
	  else
	{
	      mtx_assert (buf->bd_pl == IT_DP_PL (buf->bd_tree, buf->bd_page));
	      wi_inst.wi_n_dirty--;
	    }
	  IQ_LEAVE_TRACE (buf);
	  page_leave_inner (buf);
	  mutex_leave (&itm->itm_mtx);
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
    n_iqs++;
    dk_set_push (&mti_io_queues, (void*) iq);
    iq->iq_id = (dst) ? box_copy (dst->dst_iq_id) : NULL;
    iq->iq_mtx = mutex_allocate ();
    mutex_option (iq->iq_mtx, (char *) (iq->iq_id ? iq->iq_id : "IQ"), iq_mtx_entry_check, (void *) iq);
    thr = PrpcThreadAllocate ((thread_init_func) iq_loop, (c_use_aio == AIO_MERGING) ? MERGE_THR_SIZE : 50000, iq);
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
mtw_cpt_ck (buffer_desc_t * buf, int line)
{
  if (wi_inst.wi_checkpoint_atomic)
    {
      if (!buf->bd_tree || !buf->bd_tree->it_key || KI_TEMP == buf->bd_tree->it_key->key_id)
	return; /* no message for a temp because such can be wired down at cpt time and not writable */
      log_error ("suspect to miss a flush of L=%d in cpt, line %d", buf->bd_page, line);
    }
}


void
mt_write_dirty (buffer_pool_t * bp, int age_limit, int phys_eq_log)
{
  /* Locate, sort and write dirty buffers. */
  buffer_desc_t **bufs, **local_bufs = NULL;
  buffer_desc_t *buf;
  int inx, fill = 0;
  size_t n = 0;


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
      it_map_t * buf_itm;
      buf = &bp->bp_bufs[inx];
      if (wi_inst.wi_checkpoint_atomic && !buf->bd_is_dirty)
	continue;
      if (age_limit && ( (bp->bp_ts - buf->bd_timestamp)) < age_limit)
	{
	  mtw_cpt_ck (buf, __LINE__);
	  continue;
	}
      if (bp_buf_enter (buf, &buf_itm))
	{
	  if (!buf->bd_is_write
	      && !buf->bd_readers
	      && !buf->bd_write_waiting
	      && !buf->bd_iq
	      && buf->bd_is_dirty
	      )
	    {
	      if (buf->bd_being_read)
		GPF_T1 ("planning write of buffer being read");
	      buf->bd_readers++;
	      bufs[fill++] = buf;
	    }
	  else
	    mtw_cpt_ck (buf, __LINE__);
	  mutex_leave (&buf_itm->itm_mtx);
	}
      else
	mtw_cpt_ck (buf, __LINE__);
    }
  LEAVE_BP (bp);
  iq_schedule (bufs, fill);
  IN_BP (bp);
  if (!local_bufs)
    bp->bp_sort_tmp = bufs;
  else
    dk_free (local_bufs, n);
}





int c_flush_batch = 128 * 1024; /* 1GB worth of buffers */

#define BUFS_BATCH 10000


dp_addr_t
dbs_schedule_write (dbe_storage_t * dbs, buffer_desc_t ** bufs, int n_bufs)
{
  /* Locate, sort and write dirty buffers. */
  dp_addr_t max_dp;
  buffer_desc_t *buf;
  int inx, fill = 0, binx;
  size_t n = 0;
  DO_BOX (buffer_pool_t *, bp, binx, wi_inst.wi_bps)
    {
      IN_BP (bp);
      for (inx = 0; inx < n_bufs; inx++)
	{
	  buffer_desc_t * buf = bufs[inx];
	  if (buf < bp->bp_bufs || buf > &bp->bp_bufs[bp->bp_n_bufs - 1])
	    continue;
	  it_map_t * buf_itm;
      if (wi_inst.wi_checkpoint_atomic && !buf->bd_is_dirty)
	continue;
      if (dbs != buf->bd_storage)
	{
	  bufs[inx] = NULL;
	  continue;
	}
      if (bp_buf_enter (buf, &buf_itm))
	{
	  if (!buf->bd_is_write
	      && !buf->bd_readers
	      && !buf->bd_write_waiting
	      && !buf->bd_iq
	      && buf->bd_is_dirty
	      )
	    {
	      if (buf->bd_being_read)
		GPF_T1 ("planning write of buffer being read");
	      buf->bd_readers++;
	    }
	  else
	    bufs[inx] = NULL;
	  mutex_leave (&buf_itm->itm_mtx);
	}
      else
	bufs[inx] = NULL;
	}
      LEAVE_BP (bp);
    }
  END_DO_BOX;
  max_dp = iq_schedule (bufs, n_bufs);
  return max_dp;
}

long tc_n_flush;
long tc_dirty_after_flush;
sys_timer_t sti_iq_sync;
sys_timer_t sti_sync;
sys_timer_t sti_flush_sched;


int
dbs_dirty_count ()
{
  int binx, inx, n_dirty = 0;
  DO_BOX (buffer_pool_t *, bp, binx, wi_inst.wi_bps)
    {
      buffer_desc_t * buf;
      for (inx = 0; inx < bp->bp_n_bufs; inx++)
	{
	  buf = &bp->bp_bufs[inx];
	  if (buf->bd_is_dirty)
	    n_dirty++;
	}
    }
  END_DO_BOX;
  return n_dirty;
}

extern int buf_sort_dirty;

dp_addr_t
dbs_sched_low_dirty (dbe_storage_t * dbs, dp_addr_t min_dp, int * n_sched)
{
  buffer_desc_t ** all_bufs;
  uint32 start;
  int fill = 0, ctr = 0, fill2 = 0, n_bufs, b_fill, org_n_bufs;
  dp_addr_t sort_limit, max_dp;
  buffer_desc_t ** bufs;
  int bpinx, inx;
  uint64 dp_sum = 0;
  mem_pool_t * mp = mem_pool_alloc ();
  dk_set_t buf_list = NULL;
  bufs = (buffer_desc_t **)mp_alloc_box (mp, sizeof (caddr_t) * BUFS_BATCH, DV_NON_BOX);
  mp_set_push (mp, &buf_list, (void*)bufs);
  DO_BOX (buffer_pool_t *, bp, bpinx, wi_inst.wi_bps)
    {
      for (inx = 0; inx < bp->bp_n_bufs; inx++)
	{
	  buffer_desc_t * buf = &bp->bp_bufs[inx];
	  if (buf->bd_is_dirty && buf->bd_storage == dbs && buf->bd_physical_page > min_dp)
	    {
	      dp_sum += buf->bd_physical_page;
	      bufs[fill++] = buf;
	      if (fill == BUFS_BATCH)
		{
		  bufs = mp_alloc_box (mp, sizeof (caddr_t) * BUFS_BATCH, DV_NON_BOX);
		  mp_set_push (mp, &buf_list, (void*)bufs);
		  fill = 0;
		}
	    }
	}
    }
  END_DO_BOX;
  n_bufs = fill + (BUFS_BATCH * (dk_set_length (buf_list) - 1));
  org_n_bufs = n_bufs;
  sort_limit = DP_MAX;
  while (n_bufs > c_flush_batch * 2 && ctr < 4)
    {
      int n_below = 0;
      int b_fill = fill;
      dp_addr_t avg = dp_sum / n_bufs;
      dp_sum = 0;
      DO_SET (buffer_desc_t **, bufs, &buf_list)
	{
	  for (inx = 0; inx < b_fill; inx++)
	    {
	      buffer_desc_t * buf = bufs[inx];
	      if (buf->bd_physical_page < avg)
		{
		  dp_sum += buf->bd_physical_page;
		  n_below++;
		}	
	    }
	  b_fill = BUFS_BATCH;
	}
      END_DO_SET();
      n_bufs = n_below;
      sort_limit = avg;
      ctr++;
    }
  all_bufs = (buffer_desc_t**)mp_alloc_box (mp, n_bufs * sizeof (caddr_t), DV_NON_BOX);
  b_fill = fill;
  DO_SET (buffer_desc_t **, bufs, &buf_list)
    {
      for (inx = 0; inx < fill; inx++)
	{
	  buffer_desc_t * buf = bufs[inx];
	  if (buf->bd_physical_page < sort_limit)
	    {
	      all_bufs[fill2++] = buf;
	      if (fill2 >= n_bufs)
		break; /* is a dirty read, can be some that were not below are so now */
	    }
	}
      fill = BUFS_BATCH;
    }
  END_DO_SET();
  buf_sort_dirty = 1;
  buf_sort (all_bufs, fill2, (sort_key_func_t) bd_phys_page_key);
  buf_sort_dirty = 0;
  *n_sched = MIN (n_bufs, c_flush_batch);
  STI_START;
  max_dp = dbs_schedule_write (dbs, all_bufs, *n_sched);
  STI_END (sti_flush_sched);
  mp_free (mp);
  return org_n_bufs > c_flush_batch ? max_dp : DP_MAX;
}


void
mt_flush_all ()
{
  int total_sched = 0, dirty_after = 0;
  long init_flushed = tc_n_flush;
  dp_addr_t min_dp;
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
    {
      if (dbs->dbs_slices || DBS_TEMP == dbs->dbs_type)
	continue;
      min_dp = 0;
      while (min_dp < DP_MAX)
	{
	  int n_sched;
	  uint32 start;
	  min_dp = dbs_sched_low_dirty (dbs, min_dp, &n_sched);
	  total_sched += n_sched;
	  STI_START;
	  iq_shutdown (IQ_SYNC);
	  sti_cum (&sti_iq_sync, &__sti);
	  dbs_sync_disks (dbs);
	  tc_n_flush += n_sched;
	  STI_END (sti_sync);
	}
      
    }
  END_DO_SET();
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
    {
      if (dbs->dbs_slices)
	continue;
      dirty_after += dbs_dirty_count (dbs);
      tc_dirty_after_flush += dirty_after;
    }
  END_DO_SET();
}


void
mt_write_start (int n_oldest)
{
  int inx;
  if (mti_writes_queued > 10
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


extern semaphore_t * bp_flush_sem;
extern du_thread_t * bp_flush_thr;
void bp_flush_thread_func (void * arg);


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
  bp_flush_sem = semaphore_allocate (0);
  bp_flush_thr = PrpcThreadAllocate ((thread_init_func) bp_flush_thread_func, 100000, NULL)->dkt_process;
}



