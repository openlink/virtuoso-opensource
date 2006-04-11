/*
 *  neodisk.c
 *
 *  $Id$
 *
 *  Neodisk Checkpoint
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
#include "sqlfn.h"
#include "srvstat.h"

#ifdef MAP_DEBUG
# define dbg_map_printf(a) printf a
#else
# define dbg_map_printf(a)
#endif


long atomic_cp_msecs;
int auto_cpt_scheduled = 0;


int
isp_can_reuse_logical (index_space_t * isp, dp_addr_t dp)
{
  /* true if page is remapped in checkpoint and there is no remap
     where log = phys */
  index_tree_t *it = isp->isp_tree;
  dp_addr_t cp_remap = (dp_addr_t) DP_CHECKPOINT_REMAP (it->it_storage, dp);
  if (isp != it->it_commit_space)
    GPF_T1 ("isp_can_reuse_logical for non-commit space.");
  if (cp_remap)
    return 1;
  else
    return 0;
}


void
isp_free_remap (index_space_t * isp, dp_addr_t logical, dp_addr_t remap)
{
  /* Free the remap space of logical in THIS space, if appropriate
     Use in rollback, delta merge, snapshot close */
  ASSERT_IN_MAP (isp->isp_tree);
  if (!remap)
    remap = (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (logical), isp->isp_remap);
  if (remap != logical)
    {
      dbs_free_disk_page (isp->isp_tree->it_storage, remap);
      LEAVE_DBS (isp->isp_tree->it_storage);
    }
  else
    {
      /* log == phys. Free is OK if not remapped in checkpoint */
      if (!DP_CHECKPOINT_REMAP (isp->isp_tree->it_storage, logical))
	{
	  dbs_free_disk_page (isp->isp_tree->it_storage, logical);
	  LEAVE_DBS (isp->isp_tree->it_storage);
	}
    }
}


index_space_t *isp_to_g;
index_space_t *isp_from_g;
long busy_pre_image_scrap;




#ifdef CHECKPOINT_TIMING
long start_killing = 0, all_trx_killed = 0, cp_is_attomic = 0, cp_is_over = 0;
#endif
void
cpt_rollback (int may_freeze)
{
#ifdef CHECKPOINT_TIMING
  start_killing = get_msec_real_time();
#endif
  wi_inst.wi_is_checkpoint_pending = 1;

 next:
  ASSERT_IN_TXN;
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      int stat = lt->lt_status;
#ifdef CHECK_LT_THREADS
      volatile int lt_threads = lt->lt_threads;
      volatile int lt_lw_threads = lt->lt_lw_threads;
      volatile int lt_close_ack_threads = lt->lt_close_ack_threads;
      volatile int lt_vdb_threads = lt->lt_vdb_threads;
      volatile int lt_status = lt->lt_status;
#endif
      switch (stat)
	{
	case LT_BLOWN_OFF:
	case LT_CLOSING:
	case LT_COMMITTED:
	  rdbg_printf (("trx %lx killed by checkpoint while closing\n", lt));
	  lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
	  goto next;
	case LT_FREEZE:
	  if (!lt->lt_close_ack_threads && lt->lt_threads && !lt->lt_vdb_threads && !lt->lt_lw_threads)
	    {
	      TC(tc_cpt_rollback_retry);
	      lt_wait_until_dead (lt);
	      goto next;
	    }
	  break;
	case LT_DELTA_ROLLED_BACK:
	  break;  /* nothing to do, this one is stopped for the checkpoint. */
	case LT_PENDING:
	  if (!lt->lt_threads)
	    {
	      /* if not running, do nothing if no delta for cpt.  If for atomic, do nothing if no locks */
	      if (LT_KILL_FREEZE == may_freeze
		  && !LT_HAS_DELTA (lt))
		break;
	      if (!lt->lt_locks)
		break;
	    }
	  if (lt->lt_lw_threads
	      && !LT_HAS_DELTA (lt) && LT_KILL_FREEZE == may_freeze)
	    break;

	  TC (tc_cpt_rollback);
	  rdbg_printf (("trx %lx killed by checkpoint\n", lt));
	  lt->lt_error = LTE_CHECKPOINT;
	  lt_kill_other_trx (lt, NULL, NULL, may_freeze);
	  goto  next;

	default:  GPF_T1 ("Unexpected lt_status in cpt_rollback");
	}
    }
  END_DO_SET();


#ifdef CHECKPOINT_TIMING
  all_trx_killed = get_msec_real_time();
#endif
  ASSERT_IN_TXN;
#ifdef CHECKPOINT_TIMING
  cp_is_attomic = get_msec_real_time();
#endif
  rdbg_printf (("Checkpoint atomic\n"));
}


typedef struct server_lock_s
{
  int		sl_count;
  du_thread_t *	sl_owner;
  dk_set_t	sl_waiting;
} server_lock_t;


server_lock_t server_lock;


void
lt_wait_checkpoint (void)
{
  ASSERT_IN_TXN;
  if (THREAD_CURRENT_THREAD == server_lock.sl_owner)
    return;
  while (wi_inst.wi_is_checkpoint_pending)
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      dk_set_push (&wi_inst.wi_waiting_checkpoint, (void*) self);
      TC (tc_cpt_lt_start_wait);
      rdbg_printf (("thread wait for checkpoint end\n"));
      LEAVE_TXN;
      semaphore_enter (self->thr_sem);
      IN_TXN;
    }
}


void
cpt_over (void)
{
  ASSERT_IN_TXN;
  DO_SET (du_thread_t *, thr, &wi_inst.wi_waiting_checkpoint)
  {
    semaphore_leave (thr->thr_sem);
  }
  END_DO_SET();
  wi_inst.wi_is_checkpoint_pending = 0;
  dk_set_free (wi_inst.wi_waiting_checkpoint);
  wi_inst.wi_waiting_checkpoint = NULL;
#ifdef CHECKPOINT_TIMING
  cp_is_over = get_msec_real_time();
#endif
}




void
dbs_read_checkpoint_remap (dbe_storage_t * dbs, dp_addr_t from)
{
  cp_buf->bd_storage = dbs;
  while (from)
    {
      int inx;
      dk_set_push (&dbs->dbs_cp_remap_pages, DP_ADDR2VOID (from));
      cp_buf->bd_page = from;
      cp_buf->bd_physical_page = from;
      buf_disk_read (cp_buf);
      for (inx = DP_DATA; inx <= PAGE_SZ - 8; inx += 8)
	{
	  dp_addr_t logical = LONG_REF (cp_buf->bd_buffer + inx);
	  dp_addr_t physical = LONG_REF (cp_buf->bd_buffer + inx + 4);
	  if (logical)
	    {
	      if (!physical)
		GPF_T1 ("Read remap to zero");
	      sethash (DP_ADDR2VOID (logical),
		       dbs->dbs_cpt_remap,
		       DP_ADDR2VOID (physical));
	    }
	}
      from = LONG_REF (cp_buf->bd_buffer + DP_OVERFLOW);
    }
}


int
cpt_write_remap (dbe_storage_t * dbs)
{
  long n_written = 0;
  dk_hash_iterator_t hit;
  int cp_page_fill;
  dk_set_t cp_remap_pages;
  long n_remaps;
  int n_pages;

  /* Initialization */
  cp_buf->bd_storage = dbs;
  cp_page_fill = DP_DATA;

  cp_remap_pages = dbs->dbs_cp_remap_pages;
  n_remaps = dbs->dbs_cpt_remap->ht_count;
  n_pages = dk_set_length (cp_remap_pages);

  if (n_remaps > (long) (n_pages * REMAPS_ON_PAGE))
    {
      int n_more = n_remaps - (n_pages * REMAPS_ON_PAGE);
      int ctr;
      dp_addr_t page;
      for (ctr = 0; ctr < n_more; ctr += REMAPS_ON_PAGE)
	{
	  page = dbs_get_free_disk_page (dbs, 0);
	  if (page == 0)
	    return 0;
	  dk_set_push (&dbs->dbs_cp_remap_pages, DP_ADDR2VOID (page));
	}
    }
  cp_remap_pages = dbs->dbs_cp_remap_pages;
  dk_hash_iterator (&hit, dbs->dbs_cpt_remap);

  cp_remap_pages = dbs->dbs_cp_remap_pages;
  while (cp_remap_pages)
    {
      void *log = NULL, *phys = NULL;
      if (dk_hit_next (&hit, &log, &phys))
	n_written++;
      LONG_SET (cp_buf->bd_buffer + cp_page_fill, (dp_addr_t) (ptrlong) log);
      LONG_SET (cp_buf->bd_buffer + cp_page_fill + 4, (dp_addr_t) (ptrlong) phys);
      cp_page_fill += 8;
      if (cp_page_fill >= PAGE_SZ - 8)
	{
	  dp_addr_t next_remap = cp_remap_pages->next
	      ? (dp_addr_t) (uptrlong) cp_remap_pages->next->data
	      : 0;
	  cp_buf->bd_page = (dp_addr_t) (uptrlong) cp_remap_pages->data;
	  cp_buf->bd_physical_page = cp_buf->bd_page;

	  LONG_SET (cp_buf->bd_buffer + DP_OVERFLOW, next_remap);
	  SHORT_SET (cp_buf->bd_buffer + DP_FLAGS, DPF_CP_REMAP);
	  buf_disk_write (cp_buf, 0);
	  cp_remap_pages = cp_remap_pages->next;
	  cp_page_fill = DP_DATA;
	}
    }
  if (n_written != n_remaps)
    GPF_T1 ("Remap table inconsistent");
  return 1;
}


/*
   Neodisk checkpoint logic:

   - Read pages to unremap. Prefer unremaps already in RAM
   - An unremap is a page of remapped checkpoint not mapped back.
   - Gp atomic, kill snapshots
   - Set unremappable pages to dirty, write out.
   - Merge commit remap into checkpoint remap.
   - write checkpoint remap out.
 */


/*
   To merge a commit delta into checkpoint remap:
   if phys == log, remove from checkpoint remap.
   if other remap, insert into checkpoint remap.
 */

int cpt_unremaps_refused = 0;


int
cpt_may_unremap_page (dbe_storage_t * dbs, dp_addr_t dp)
{
  /* Only such checkpoint remapped pages that are not also
     remapped in transaction deltas can be unremapped */
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      if (gethash (DP_ADDR2VOID (dp), it->it_commit_space->isp_remap))
	{
	  cpt_unremaps_refused++;
	  return 0;
	}
    }
  END_DO_SET ();
  return 1;
}


dbe_storage_t * cpt_dbs;

void
cpt_neodisk_page (void *key, void *value)
{
  dp_addr_t logical = (dp_addr_t) (uptrlong) key;
  dp_addr_t physical = (dp_addr_t) (uptrlong) value;
  buffer_desc_t *before_image, *after_image;
  if (!physical)
    GPF_T1 ("Zero phys page");
  if (physical == DP_DELETED)
    {
      dp_addr_t cp_remap =
	  (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
      if (cp_remap)
	{
	  remhash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
	  dbs_free_disk_page (cpt_dbs, cp_remap);
	}
      dbs_free_disk_page (cpt_dbs, logical);
      dp_set_backup_flag (cpt_dbs, logical, 0);
      before_image = (buffer_desc_t *) gethash (DP_ADDR2VOID (logical), isp_to_g->isp_dp_to_buf);
      if (before_image)
	{
	  remhash (DP_ADDR2VOID (logical), isp_to_g->isp_dp_to_buf);
	  before_image->bd_space = NULL;
	  log_info ("before image not expected during chekpoint.");
	  buf_set_last (before_image);
	}
      return;
    }

  dp_set_backup_flag (cpt_dbs, logical, 1);

  before_image =
      (buffer_desc_t *) gethash (DP_ADDR2VOID (logical), isp_to_g->isp_dp_to_buf);
  after_image =
      (buffer_desc_t *) gethash (DP_ADDR2VOID (logical), isp_from_g->isp_dp_to_buf);
  if (logical == physical)
    {
      dp_addr_t cp_remap =
	  (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
      if (cp_remap)
	{
	  remhash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
	  dbs_free_disk_page (cpt_dbs, cp_remap);
	}
    }
  else
    {
      dp_addr_t cp_remap =
	  (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
      if (cp_remap)
	{
	  dbs_free_disk_page (cpt_dbs, cp_remap);
	}
      sethash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap, DP_ADDR2VOID (physical));
    }

  if (before_image)
    {
      GPF_T1 ("before image in cpt not expected. No buffers in cpt space");
      remhash (DP_ADDR2VOID (logical), isp_to_g->isp_dp_to_buf);
      buf_set_last (before_image);
    }
  if (after_image)
    {
      if (after_image->bd_is_dirty
	  && logical != physical
	  && cpt_may_unremap_page (cpt_dbs, logical))
	{
	  /* dirty after image will go to logical anyway.
	     May just as well write it to logical as to remap.
	     Still check that no uncommitted txn has it remapped log = phys. */

	  remhash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
	  dbs_free_disk_page (cpt_dbs, physical);
	  rdbg_printf (("[C Unremap L %ld R %ld ]", logical, physical));

	  after_image->bd_physical_page = after_image->bd_page;
	}
    }
}


int
cpt_is_page_remapped (dp_addr_t page)
{
  DO_SET (index_tree_t *, it, &cpt_dbs->dbs_trees)
    {
      if (gethash (DP_ADDR2VOID (page), it->it_commit_space->isp_remap))
	return 1;
    }
  END_DO_SET();
  return 0;
}


buffer_desc_t *
dbs_buf_by_dp (dbe_storage_t * dbs, dp_addr_t dp)
{
  buffer_desc_t * buf = NULL;
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      buf = (buffer_desc_t *) gethash (DP_ADDR2VOID (dp), it->it_commit_space->isp_dp_to_buf);
      if (buf)
	return buf;
      buf = (buffer_desc_t *) gethash (DP_ADDR2VOID (dp), it->it_checkpoint_space->isp_dp_to_buf);
      if (buf)
	return buf;
    }
  END_DO_SET();
  return NULL;
}


void
cpt_unremap_page_in_ram (void *key, void *value)
{
  dp_addr_t logical = (dp_addr_t) (uptrlong) key;
  dp_addr_t physical = (dp_addr_t) (uptrlong) value;

  /****** If page IS REMAPPED in CP and NOT remapped in
    commit OR PENDING TXN, you may unremap */
  if (!cpt_is_page_remapped (logical)
      && cpt_may_unremap_page (cpt_dbs, logical))
    {
      buffer_desc_t *image = dbs_buf_by_dp (cpt_dbs, logical);
      if (image)
	{
	  image->bd_physical_page = logical;
	  image->bd_is_dirty = 1;
	  remhash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
	  dbs_free_disk_page (cpt_dbs, physical);
	  rdbg_printf (("[U L %ld R %ld ]", logical, physical));
	}
    }
}


void
cpt_unremap_in_ram (void)
{
  /* if happens to be any buffers in RAM that are checkpoint
     remapped and not mapped back. Return number */
  maphash (cpt_unremap_page_in_ram,
	   cpt_dbs->dbs_cpt_remap);
}


int mcp_batch;
int mcp_fill;
jmp_buf_splice mcp_next_batch;
dk_hash_t *remap;



remap_t *mcp_remaps;
remap_t **mcp_remap_ptrs;


void
cpt_mark_unremap (void *key, void *value)
{
  dp_addr_t logical = (dp_addr_t) (uptrlong) key;
  dp_addr_t physical = (dp_addr_t) (uptrlong) value;

  /* mark into mcp_batch */
  if (logical == physical)
    {
      /* no move needed. Remove remap and return */
      GPF_T1 ("Logical = physical remap not allowed in checkpoint");
    }
  if (cpt_is_page_remapped (logical))
    return;
  mcp_remaps[mcp_fill].rm_physical = physical;
  mcp_remaps[mcp_fill].rm_logical = logical;
  mcp_remap_ptrs[mcp_fill] = &mcp_remaps[mcp_fill];
  mcp_fill++;
  if (mcp_fill == mcp_batch)
    longjmp_splice (&mcp_next_batch, 1);
}


dp_addr_t
remap_phys_key (remap_t * r)
{
  return (r->rm_physical);
}


dk_mutex_t *checkpoint_mtx;

it_cursor_t *mcp_itc;


index_tree_t *
buf_belongs_to (buffer_desc_t * buf)
{
  /* will contain key and fragment identifier */
  return NULL;
}


void
cpt_place_buffers ()
{
  /* unremapped pages have been read into the dbs_cpt_tree.  Now place these into their correct trees */
  ptrlong dp;
  buffer_desc_t * buf;
  dk_hash_iterator_t hit;
  dk_hash_iterator (&hit, cpt_dbs->dbs_cpt_tree->it_commit_space->isp_dp_to_buf);
  while (dk_hit_next (&hit, (void **) &dp, (void**) &buf))
    {
      index_tree_t *it = buf_belongs_to (buf);
      if (it)
	{
	  dp_addr_t dp = buf->bd_page;
	  buf->bd_page = 0;
	  IN_PAGE_MAP (it);
	  isp_set_buffer (it->it_commit_space, dp, dp, buf);
	  LEAVE_PAGE_MAP (it);
	}
      else
	{
	  buf->bd_space = NULL;
	  buf_set_last (buf);
	  buf->bd_storage = NULL;
	}
    }
  clrhash (cpt_dbs->dbs_cpt_tree->it_commit_space->isp_dp_to_buf);
}


void
cpt_preread_unremaps (int stay_inside)
{
  int i;
  mcp_fill = 0;
  if (0 == setjmp_splice (&mcp_next_batch))
    {
      maphash (cpt_mark_unremap, remap);
    }
  buf_sort ((buffer_desc_t **) mcp_remap_ptrs, mcp_fill,
      (sort_key_func_t) remap_phys_key);

  rdbg_printf (("Going to unremap %d old pages\n", mcp_fill));

  for (i = 0; i < mcp_fill; i++)
    {
      buffer_desc_t *buf;
      do
	{
	  mcp_itc->itc_page = 0;
	  mcp_itc->itc_tree = cpt_dbs->dbs_cpt_tree;
	  mcp_itc->itc_space = cpt_dbs->dbs_cpt_tree->it_commit_space;
	  ITC_IN_MAP (mcp_itc);
	  buf = dbs_buf_by_dp (cpt_dbs, mcp_remap_ptrs[i]->rm_logical);
	  if (!buf)
	    buf = page_fault_map_sem (mcp_itc, mcp_remap_ptrs[i]->rm_logical,
	      0);
	  if (!buf)
	    {
	      rdbg_printf (("Second read in checkpoint preread.\n"));
	    }
	  ITC_LEAVE_MAP (mcp_itc);
	}
      while (!buf);
    }
}




#ifdef UNIX
# define WITHOUT_SIGNALS \
  {  \
    sigset_t oldsig, newsig; \
    sigemptyset (&newsig); \
    sigaddset (&newsig, SIGTERM); \
    sigaddset (&newsig, SIGINT); \
    sigprocmask (SIG_BLOCK, &newsig, &oldsig);

# define RESTORE_SIGNALS \
    sigprocmask (SIG_SETMASK, & oldsig, NULL); \
  }


#else
# define WITHOUT_SIGNALS
# define RESTORE_SIGNALS
#endif


#define CHECKPOINT_IN_PROGRESS_FILE "checkpoint_in_progress"


void
wi_write_dirty (void)
{
  int inx;
  DO_BOX (buffer_pool_t *, bp, inx, wi_inst.wi_bps)
    {
      bp_write_dirty (bp, 0, 0, ALL_DIRTY);
    }
  END_DO_BOX;
}



void
dbs_backup_check (dbe_storage_t * dbs)
{
#ifdef DEBUG
  int n;
  for (n = 0; n < dbs->dbs_n_pages; n++)
    {
      if (dp_backup_flag (dbs, n)
	  && dbs_is_free_page (dbs, n))
	{
	  printf (" dp=%d is in backup set and is free\n");
	  GPF_T1 ("page in backup set and free");
	}
    }
#endif
}

void
dbs_checkpoint (dbe_storage_t * dbs, char *log_name, int shutdown)
{
  int mcp_delta_count, inx;
  int volatile all_unremapped;
  long start_atomic;
  FILE *checkpoint_flag_fd = NULL;
  mcp_batch = cp_unremap_quota;

  mcp_remaps = (remap_t *) dk_alloc (mcp_batch * sizeof (remap_t));
  mcp_remap_ptrs = (remap_t **) dk_alloc (mcp_batch * sizeof (caddr_t));

  mcp_delta_count = 0;

  DO_BOX (buffer_pool_t *, bp, inx, wi_inst.wi_bps)
    {
      IN_BP (bp);
      mt_write_dirty (bp, 0, 0 /*PHYS_EQ_LOG*/ );
      LEAVE_BP (bp);
    }
  END_DO_BOX;
  iq_shutdown (IQ_SYNC);

  DO_BOX (buffer_pool_t *, bp, inx, wi_inst.wi_bps)
    {
      IN_BP (bp);
      mt_write_dirty (bp, 0, 0 /*PHYS_EQ_LOG*/ );
      LEAVE_BP (bp);
    }
  END_DO_BOX;

  cpt_rollback (LT_KILL_FREEZE);
  iq_shutdown (IQ_STOP);
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      it_cache_check (it);
    }
  END_DO_SET();

  dbs_backup_check (dbs);
  WITHOUT_SIGNALS
  {
    checkpoint_flag_fd = fopen(CHECKPOINT_IN_PROGRESS_FILE, "a");
    if (checkpoint_flag_fd != NULL)
      {
	fprintf(checkpoint_flag_fd,
		"If this file exists then a checkpoint started at %ld "
		"and has not finished yet",
		get_msec_real_time ());
	fclose(checkpoint_flag_fd);
      }

    mcp_itc = itc_create (NULL, NULL);
    rdbg_printf (("\nCheckpoint atomic.\n"));
    sch_save_roots (wi_inst.wi_schema);
    dbs_write_registry (dbs);
    start_atomic = get_msec_real_time ();
    DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
      {
	index_tree_t *del_it;
	cpt_dbs = dbs;
	remap = dbs->dbs_cpt_remap;
	DO_SET (index_tree_t *, it, &dbs->dbs_trees)
	  {
	    mcp_itc->itc_thread = THREAD_CURRENT_THREAD;

	    isp_to_g = it->it_checkpoint_space;
	    isp_from_g = it->it_commit_space;
	    if (isp_to_g->isp_dp_to_buf->ht_count > 0 || isp_to_g->isp_remap->ht_count > 0)
	      printf ("isp %p has things in its cpt space\n" , (void *)(it));
	    rdbg_printf (("%s %ld\n",
		  it->it_key ? it->it_key->key_name : "no key",
		  (long) it->it_commit_space->isp_remap->ht_count));

	    maphash (cpt_neodisk_page, it->it_commit_space->isp_remap);

	    clrhash (it->it_commit_space->isp_remap);
	  }
	END_DO_SET();
	wi_write_dirty ();

	while (NULL != (del_it = (index_tree_t *) dk_set_pop (&dbs->dbs_deleted_trees)))
	  {
	    mcp_itc->itc_thread = THREAD_CURRENT_THREAD;

	    isp_to_g = del_it->it_checkpoint_space;
	    isp_from_g = del_it->it_commit_space;

	    maphash (cpt_neodisk_page, del_it->it_commit_space->isp_remap);

	    clrhash (del_it->it_commit_space->isp_remap);
	  }

	all_unremapped = 0;
	while (1)
	  {
	    uint32 n_remaps = remap->ht_count;
	    if (all_unremapped || n_remaps <= dbs->dbs_max_cp_remaps)
	      {
		if (0 == cpt_write_remap (dbs))
		  {
		    log_error ("Checkpoint remap write failed, %ld remap pages",
			       dbs->dbs_cpt_remap->ht_count);
		  }
		else
		  break;
	      }
	    cpt_preread_unremaps (1);
	    cpt_unremap_in_ram ();
	    wi_write_dirty ();
	    if (cpt_dbs->dbs_cpt_remap->ht_count == (uint32) n_remaps)
	      all_unremapped = 1;
	  }
	cpt_place_buffers ();
	dbs_write_page_set (dbs, dbs->dbs_free_set);
	dbs_write_page_set (dbs, dbs->dbs_incbackup_set);
	dbs_write_cfg_page (dbs, 0);
	IN_DBS (dbs);
	LEAVE_DBS (dbs);
	if (DBS_PRIMARY == dbs->dbs_type)
	  log_checkpoint (dbs, log_name);
      }
    END_DO_SET();
    mcp_itc->itc_is_in_map_sem = 0;
    itc_free (mcp_itc);
    mcp_itc = NULL;
    dbg_printf (("Checkpoint made. %d delta pages.\n", mcp_delta_count));

    dk_free ((caddr_t) mcp_remaps, mcp_batch * sizeof (remap_t));
    dk_free ((caddr_t) mcp_remap_ptrs, mcp_batch * sizeof (caddr_t));
    unlink(CHECKPOINT_IN_PROGRESS_FILE);
    rdbg_printf (("Checkpoint atomic over.\n"));
  }
  RESTORE_SIGNALS;
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      it_cache_check (it);
    }
  END_DO_SET();
  dbs_backup_check (dbs);
  if (CPT_NORMAL == shutdown)
    cpt_over ();
  if (CPT_SHUTDOWN != shutdown)
    iq_restart ();

  auto_cpt_scheduled = 0;
  atomic_cp_msecs += get_msec_real_time () - start_atomic;

  LEAVE_TXN;
  dbs_sync_disks (dbs);
  IN_TXN;
}


int
cpt_count_mapped_back (dbe_storage_t * dbs)
{
  int ctr = 0;
  dk_hash_iterator_t hit;
  void *log, *phys;
  dk_hash_iterator (&hit, dbs->dbs_cpt_remap);
  while (dk_hit_next (&hit, &log, &phys))
    {
      if (cpt_is_page_remapped ((dp_addr_t) (ptrlong) log))
	ctr++;
    }
  return ctr;
}


void
srv_global_unlock (client_connection_t *cli, lock_trx_t *lt)
{
  if (server_lock.sl_owner != THREAD_CURRENT_THREAD)
    GPF_T1 ("not owner of atomic lock");
  server_lock.sl_count--;
  if (0 == server_lock.sl_count)
    {
      IN_TXN;
      if (lt->lt_threads)
        lt_commit (lt, TRX_CONT);
      LEAVE_TXN;
      server_lock.sl_owner = NULL;
      IN_TXN;
      cpt_over ();
      LEAVE_TXN;
      lt->lt_is_excl = 0;
      lt->lt_replicate = (caddr_t*) box_copy_tree ((caddr_t) cli->cli_replicate);;
      LEAVE_CPT_1;
    }
}


void
srv_global_lock (query_instance_t * qi, int flag)
{
  lock_trx_t * lt = qi->qi_trx;
  /*GK: in roll forward this is a no-op */
  if (in_log_replay)
    return;
  if (flag)
    {
      if (THREAD_CURRENT_THREAD == server_lock.sl_owner)
	{
	  server_lock.sl_count++;
	  return;
	}
      if (qi->qi_trx->lt_locks)
	{
	  int rc;
	  caddr_t err;
	  IN_TXN;
          rc = lt_commit (qi->qi_trx, TRX_CONT);
	  LEAVE_TXN;
          if (rc != LTE_OK)
	    {
	      MAKE_TRX_ERROR (rc, err, LT_ERROR_DETAIL (qi->qi_trx));
	      sqlr_resignal (err);
	    }
	}
      IN_CPT(lt);
      server_lock.sl_count = 1;
      lt->lt_isolation = ISO_UNCOMMITTED;
      lt->lt_is_excl = 1;
      lt->lt_replicate = REPL_NO_LOG;
      IN_TXN;
      cpt_rollback (LT_KILL_ROLLBACK);
      server_lock.sl_owner = THREAD_CURRENT_THREAD;
      lt_threads_set_inner (lt, 1);
      LEAVE_TXN;
      return;
    }
  else
    {
      if (server_lock.sl_owner != THREAD_CURRENT_THREAD)
	sqlr_new_error ("42000", "SR109", "Cannot free global server lock if one does not hold it");
      srv_global_unlock (qi->qi_client, lt);
    }
}


int
cpt_is_global_lock ()
{
  if (server_lock.sl_owner
      && server_lock.sl_owner != THREAD_CURRENT_THREAD)
    return 1;
  return 0;
}


int
srv_have_global_lock (du_thread_t *thr)
{
  return (server_lock.sl_owner && server_lock.sl_owner == thr);
}
