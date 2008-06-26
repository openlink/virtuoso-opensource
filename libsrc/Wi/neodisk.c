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
#include "recovery.h"

#ifdef MAP_DEBUG
# define dbg_map_printf(a) printf a
#else
# define dbg_map_printf(a)
#endif

#if 0
#define uc_printf(a) printf a
#else
#define uc_printf(a)
#endif

long atomic_cp_msecs;
int auto_cpt_scheduled = 0;


int
it_can_reuse_logical (index_tree_t * it, dp_addr_t dp)
{
  /* true if page is remapped in checkpoint and there is no remap
     where log = phys */
  dp_addr_t cp_remap = DP_CHECKPOINT_REMAP (it->it_storage, dp);
  if (cp_remap)
    return 1;
  else
    return 0;
}


void
it_free_remap (index_tree_t * it, dp_addr_t logical, dp_addr_t remap)
{
  /* Free the remap space of logical in THIS space, if appropriate
     Use in rollback, delta merge, snapshot close */
  it_map_t * itm = IT_DP_MAP (it, logical);
  ASSERT_IN_MTX (&itm->itm_mtx);
  if (!remap)
    remap = (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (logical), &itm->itm_remap);
  if (remap != logical)
    {
      dbs_free_disk_page (it->it_storage, remap);
      LEAVE_DBS (it->it_storage);
    }
  else
    {
      /* log == phys. Free is OK if not remapped in checkpoint */
      if (!DP_CHECKPOINT_REMAP (it->it_storage, logical))
	{
	  dbs_free_disk_page (it->it_storage, logical);
	  LEAVE_DBS (it->it_storage);
	}
    }
}


index_tree_t *it_from_g;
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
	      /* if not running, do nothing for  cpt.  If for atomic, do nothing if no locks */
	      if (LT_KILL_FREEZE == may_freeze)
		break;
	      if (!lt_has_locks (lt))
		break;
	    }
	  if (lt->lt_lw_threads
	      && LT_KILL_FREEZE == may_freeze)
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
      dbs_unfreeable (dbs, from, DPF_CP_REMAP);
      cp_buf->bd_page = from;
      cp_buf->bd_physical_page = from;
      buf_disk_read (cp_buf);
      if (DPF_CP_REMAP != SHORT_REF (cp_buf->bd_buffer + DP_FLAGS))
	{
	  log_error ("cpt remap page L=%d has flag %d, not DPF_CP_MREMAP", cp_buf->bd_page, SHORT_REF (cp_buf->bd_buffer + DP_FLAGS));
	  GPF_T1 ("bad cpt remap page");
	  return;
	}
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
cpt_check_remap (dbe_storage_t * dbs)
{
  dp_addr_t from = dbs->dbs_cp_remap_pages ? (dp_addr_t) (uptrlong) dbs->dbs_cp_remap_pages->data : 0;

  cp_buf->bd_storage = dbs;
  while (from)
    {
      int inx;
      short flags;
      cp_buf->bd_page = from;
      cp_buf->bd_physical_page = from;
      buf_disk_read (cp_buf);
      flags = SHORT_REF (cp_buf->bd_buffer + DP_FLAGS);
      if (flags != DPF_CP_REMAP)
	{
	  log_error ("A bad page flags=[%d] has been detected in place of remap page in cpt.", flags);
	  return 0;
	}
      for (inx = DP_DATA; inx <= PAGE_SZ - 8; inx += 8)
	{
	  dp_addr_t logical = LONG_REF (cp_buf->bd_buffer + inx);
	  dp_addr_t physical = LONG_REF (cp_buf->bd_buffer + inx + 4);
	  if (logical && !physical)
	    {
	      log_error ("A bad remap has been detected in cpt.");
	      return 0;
	    }
	}
      from = LONG_REF (cp_buf->bd_buffer + DP_OVERFLOW);
    }
  return 1;
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
  int rc;

  rc = cpt_check_remap (dbs);

  /* there is something broken with remap pages, therefore we start with new set of pages */
  if (0 == rc)
    {
      log_error ("The remap pages has a corruption, writing the remap in a new page set.");
      dbs->dbs_cp_remap_pages = NULL;
    }

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
	  dbs_unfreeable (dbs, page, DPF_CP_REMAP);
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
      mutex_enter (&IT_DP_MAP (it, dp)->itm_mtx);
      if (gethash (DP_ADDR2VOID (dp), &IT_DP_MAP (it, dp)->itm_remap))
	{
	  mutex_leave (&IT_DP_MAP (it, dp)->itm_mtx);
	  cpt_unremaps_refused++;
	  return 0;
	}
      mutex_leave (&IT_DP_MAP (it, dp)->itm_mtx);
    }
  END_DO_SET ();
  return 1;
}


dbe_storage_t * cpt_dbs;
dk_hash_t * cpt_uncommitted_remap;
dk_hash_t * cpt_uncommitted_remap_dp; /* for the duration of the cpt, those dp's that are free in the cpt but taken in cpt plus set of uncommitted pages.  Not including blobs. */
dk_hash_t * cpt_uncommitted_lt; /* for duration of cpt, those lt's with at least one actual rollback row */


#define DP_FREE_IN_CPT(dp) \
  sethash (DP_ADDR2VOID (dp), cpt_uncommitted_remap_dp, (void*) 1)

#define PAGE_NOT_CHANGED 0
#define PAGE_UPDATED 1


int
itc_cpt_rollback_row (it_cursor_t * itc, buffer_desc_t ** buf_ret, int pos, row_lock_t * was_rl,
		  page_lock_t * pl)
{
  buffer_desc_t *buf = *buf_ret;
  lock_trx_t *lt = itc->itc_ltrx;
  db_buf_t page = buf->bd_buffer;
  long l;
  key_id_t key_id;
  if (0 == pos)
    {
      TC (tc_deld_row_rl_rb);
      return PAGE_NOT_CHANGED;  /* rl on del'd row but shared by this txn */
    }
  itc->itc_position = pos;

  key_id = SHORT_REF (page + pos + IE_KEY_ID);
  if (key_id)
    {
      rb_entry_t *rbe = lt_rb_entry (lt, page + pos, NULL, NULL, 1);
      if (!rbe)
	{
	  return PAGE_NOT_CHANGED;
	}
      sethash ((void*) itc->itc_ltrx, cpt_uncommitted_lt, (void*) 1);
      if (RB_INSERT == rbe->rbe_op)
	{
	  /* the cpt rb of an insert is just unlinking the row.  This can result in a page with 0 rows and the page still will not be deleted.
	   * Do not use or alter the page map */
	  int prev_pos = 0;
	  int del_pos;
	  for (del_pos = SHORT_REF (page + DP_FIRST); del_pos; del_pos = IE_NEXT (page + del_pos))
	    {
	      if (pos == del_pos)
		{
		  if (!prev_pos)
		    SHORT_SET (page + DP_FIRST, IE_NEXT (page + del_pos));
		  else
		    IE_SET_NEXT (page + prev_pos, IE_NEXT (page + del_pos));
		  break;
		}
	      prev_pos = del_pos;
	    }
	}
      else
	{
	  short prev_next = IE_NEXT (page + pos);
	  l = row_reserved_length (page + pos, buf->bd_tree->it_key);
	  if (rbe->rbe_row_len > ROW_ALIGN (l))
	    {
	      log_error ("In cpt of uncommitted: Space for row is shorter than pre-image"
			 " This is normally a gpf but we don't break cpt so we let it slide.");
	      return PAGE_NOT_CHANGED;
	    }
	  memcpy (page + pos,
		  rbe->rbe_string + rbe->rbe_row,
		  rbe->rbe_row_len);
	  IE_SET_FLAGS (page + pos, 0);
	  IE_SET_NEXT (page + pos, prev_next);
	}
      return PAGE_UPDATED;
    }
  return PAGE_NOT_CHANGED;
}


int
pl_cpt_rollback_page (page_lock_t * pl, it_cursor_t * itc, buffer_desc_t * buf)
{
  int change = PAGE_NOT_CHANGED, rc;
  itc->itc_page = pl->pl_page;
  if (PL_IS_PAGE (pl))
    {
      int pos = SHORT_REF (buf->bd_buffer + DP_FIRST);
      itc->itc_ltrx = pl->pl_owner;
      while (pos)
	{
	  int next_pos = IE_NEXT (buf->bd_buffer + pos);
	  rc = itc_cpt_rollback_row (itc, &buf, pos, NULL, pl);
	  change = MAX (change, rc);
	  pos = next_pos;
	}
    }
  else
    {
      DO_RLOCK (rl, pl)
      {
	
	if (PL_EXCLUSIVE == PL_TYPE (rl))
	  {
	    itc->itc_ltrx = rl->pl_owner;
	    rc = itc_cpt_rollback_row (itc, &buf, rl->rl_pos, rl, pl);
	    change = MAX (change, rc);
	  }
      }
      END_DO_RLOCK;
    }
  return change;
}


it_cursor_t *mcp_itc;


int
pl_needs_cpt_rb (page_lock_t * pl)
{
  if (!gethash (DP_ADDR2VOID (pl->pl_page), &IT_DP_MAP (mcp_itc->itc_tree, pl->pl_page)->itm_remap))
    {
      /* there is no delta for the page of the lock.  It cna't have uncommitted things */
      return 0;
    }
  if (PL_IS_PAGE (pl))
    {
      return  (PL_EXCLUSIVE == PL_TYPE (pl));
    }
  DO_RLOCK (rl, pl)
    {
      if (PL_EXCLUSIVE == PL_TYPE (rl))
	return 1;
    }
  END_DO_RLOCK;
  return 0;
}


int cpt_out_of_space = 0;
dk_set_t cpt_new_pages = NULL;

void
cpt_out_of_disk ()
{
  dp_addr_t dp;
  while ((dp = (dp_addr_t)(ptrlong)dk_set_pop (&cpt_new_pages)))
    dbs_free_disk_page (cpt_dbs, dp);
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (lt->lt_rb_hash && lt->lt_rb_hash->ht_count)
	lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
    }
  END_DO_SET();
}


#define CPT_RB_NO_DISK -1


int 
cpt_uncommitted_backup (index_tree_t * it, int inx, dk_session_t * ses, dk_hash_t * ht)
{
  static caddr_t image;
  dtp_t save[PAGE_SZ];
  dk_hash_iterator_t hit;
  page_lock_t * pl;
  void * dp;
  if (NULL == image)
    image = dk_alloc_box (PAGE_SZ + 1, DV_STRING);
  dk_hash_iterator (&hit, &it->it_maps[inx].itm_locks);
  while (dk_hit_next (&hit, &dp, (void**) &pl))
    {
      dp_addr_t cpt_remap, committed_remap, new_remap;
      buffer_desc_t * buf;
      if (!pl_needs_cpt_rb (pl))
	continue;
      mcp_itc->itc_itm1 = &it->it_maps[inx]; /*fool the assert and itc_leave_maps in page_wait_access */
      page_wait_access (mcp_itc, pl->pl_page, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
      mutex_enter (&IT_DP_MAP (it, inx)->itm_mtx);
      if (!buf || PF_OF_DELETED == buf)
	{
	  log_error ("in cpt uncommitted_backup, pl on deleted dp %d .", pl->pl_page);
	  continue;
	}
      memcpy (save, buf->bd_buffer, PAGE_SZ);
      if (PAGE_NOT_CHANGED == pl_cpt_rollback_page (pl, mcp_itc, buf))
	{
	  page_leave_inner (buf);
	  continue;
	}
      memcpy (image, buf->bd_buffer, PAGE_SZ);
      memcpy (buf->bd_buffer, save, PAGE_SZ);
      page_leave_inner (buf);
      CATCH_WRITE_FAIL (ses)
	{
	  print_int (pl->pl_page, ses);
	  print_string (image, ses);
	}
      FAILED
	{
	}
      END_WRITE_FAIL (ses);
      cpt_remap = DP_CHECKPOINT_REMAP (cpt_dbs, pl->pl_page);
      committed_remap = buf->bd_physical_page;
      if (!cpt_remap && committed_remap == pl->pl_page)
	{
	  new_remap = dbs_stop_cp == 3 ? 0 : dbs_get_free_disk_page (cpt_dbs, buf->bd_page);
	  if (!new_remap) 
	    {
	      return CPT_RB_NO_DISK;
	    }
	  dk_set_push (&cpt_new_pages, (void*)(uptrlong)new_remap);
	}


      sethash (DP_ADDR2VOID (pl->pl_page),  ht, DP_ADDR2VOID (pl->pl_page));
    }
  return 0;
}


void
cpt_uncommitted (index_tree_t * it, int inx)
{
  dp_addr_t cpt_remap, committed_remap, new_remap;
  dtp_t image[PAGE_SZ];
  dk_hash_iterator_t hit;
  page_lock_t * pl;
  void * dp;
  dk_hash_iterator (&hit, &it->it_maps[inx].itm_locks);
  while (dk_hit_next (&hit, &dp, (void**) &pl))
    {
      buffer_desc_t * buf;
      if (!pl_needs_cpt_rb (pl))
	continue;
      mcp_itc->itc_itm1 = &it->it_maps[inx]; /*fool the assert and itc_leave_maps in page_wait_access */
      page_wait_access (mcp_itc, pl->pl_page, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
      mutex_enter (&IT_DP_MAP (it, inx)->itm_mtx);
      if (!buf || PF_OF_DELETED == buf)
	{
	  log_error ("in cpt uncommitted, pl on deleted dp %d .", pl->pl_page);
	  continue;
	}
      memcpy (image, buf->bd_buffer, PAGE_SZ);
      
      if (PAGE_NOT_CHANGED == pl_cpt_rollback_page (pl, mcp_itc, buf))
	{
	  page_leave_inner (buf);
	  continue;
	}
      TC (tc_uncommit_cpt_page);
      dp_set_backup_flag (cpt_dbs, buf->bd_page, 1);
      cpt_remap = DP_CHECKPOINT_REMAP (cpt_dbs, pl->pl_page);
      if (cpt_remap)
	{
	  /* now the uncommitted page has a cpt remap.  Hence it must be mapped back to physical 
	   * Therefore write the rolled back cut to physical, the uncommitted to remap and remove the cpt remap and update the commit space remap */
	  committed_remap = (dp_addr_t)(ptrlong) gethash (DP_ADDR2VOID (pl->pl_page), &IT_DP_MAP (it_from_g, pl->pl_page)->itm_remap);
	  if (committed_remap != buf->bd_page)
	    log_error ("In cpt of uncommitted, tehre is a cpt remap of %d for logical %d with commit space remap %d, which is bad.  Expected commit space mapping back to logical", cpt_remap, buf->bd_page, buf->bd_physical_page);
	  buf->bd_physical_page = buf->bd_page;
	  buf_disk_write (buf, buf->bd_page);
	  memcpy (buf->bd_buffer, image, PAGE_SZ);
	  buf->bd_physical_page = cpt_remap;
	  buf->bd_is_dirty = 1;
	  buf_disk_write (buf, buf->bd_physical_page);
	  remhash (DP_ADDR2VOID (buf->bd_page), cpt_dbs->dbs_cpt_remap);
	  sethash (DP_ADDR2VOID (buf->bd_page),  cpt_uncommitted_remap, DP_ADDR2VOID (cpt_remap));
	  buf->bd_is_dirty = 0;
	}
      else
	{
	  /* No cpt remap. Write the rolled back page to logical */
	  committed_remap = buf->bd_physical_page;
	  if (gethash (DP_ADDR2VOID (pl->pl_page), &IT_DP_MAP (it_from_g, pl->pl_page)->itm_remap) != DP_ADDR2VOID (committed_remap))
	    log_error ("In uncommitted cpt: isp_remap and bd_physical page not consistent");
	  buf->bd_physical_page = buf->bd_page;
	  buf->bd_is_dirty = 1;
	  buf_disk_write (buf, buf->bd_physical_page);
	  memcpy (buf->bd_buffer,image, PAGE_SZ);
	  buf->bd_physical_page = committed_remap;
	  if (committed_remap == buf->bd_page)
	    {
	      /* Here we have a new page that was uncommitted.  The rolled back version goes to logical but the uncommitted version now needs a remap.
	       * Get a remap.  If not remap can be had, then do not give it a remap but this makes for a bad checkpoint.
	       * The next checkpoint will write the page as if it were new again and all writes between checkpoints  will in fact go to the checkpoint, against the rules.  
	       * To rectify this, force some unremaps at the end.  */
	      new_remap = (dp_addr_t)(ptrlong) dk_set_pop (&cpt_new_pages);
	      if (!new_remap)
	      new_remap = dbs_get_free_disk_page (cpt_dbs, buf->bd_page);
	      if (!new_remap || dbs_stop_cp == 3)
		{
		  log_error ("In checkpoint of uncommitted, there is a new page %d for which no remap can be allocated because out of space."
			     " Will try unremap and new cpt. ", buf->bd_page);
		  cpt_out_of_space = 1;
		}
	      else
		{
		  committed_remap = new_remap;
		  /*even though the new remap is allocated here,, it is not taken when starting from the cpt */
		  DP_FREE_IN_CPT (new_remap);
		  buf->bd_physical_page = committed_remap;
		  buf->bd_is_dirty = 1;
		  buf_disk_write (buf, buf->bd_physical_page);
		  buf->bd_is_dirty = 0;
		}
	    }
	  else
	    {
	      /* the remap is != the logical.  The remap is not taken in cpt space */
	      DP_FREE_IN_CPT (committed_remap);
	    }
	  sethash (DP_ADDR2VOID (buf->bd_page), cpt_uncommitted_remap, DP_ADDR2VOID (committed_remap));
	}
      page_leave_inner (buf);
    }
}

long tc_cpt_unremap_dirty;


void
cpt_neodisk_page (const void *key, void *value)
{
  dp_addr_t logical = (dp_addr_t) (uptrlong) key;
  dp_addr_t physical = (dp_addr_t) (uptrlong) value;
  buffer_desc_t *after_image;
  if (cpt_uncommitted_remap && gethash (DP_ADDR2VOID (logical), cpt_uncommitted_remap))
    return; /* this has uncommitted stuff. Allready processed */
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
      return;
    }

  dp_set_backup_flag (cpt_dbs, logical, 1);

  after_image =
    (buffer_desc_t *) gethash (DP_ADDR2VOID (logical), &IT_DP_MAP (it_from_g, logical)->itm_dp_to_buf);
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
	  GPF_T1 ("A page that has P != L should not additionally have a cpt remap");
	  dbs_free_disk_page (cpt_dbs, cp_remap);
	}
      sethash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap, DP_ADDR2VOID (physical));
    }

  if (after_image)
    {
      if (after_image->bd_is_dirty
	  && logical != physical
	  /*&& cpt_may_unremap_page (cpt_dbs, logical) */)
	{
	  /* dirty after image will go to logical anyway.
	   * May just as well write it to logical as to remap. */

	  remhash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
	  /* remhash is allowed because the cpt remap might have been made in the sethash above */
	  dbs_free_disk_page (cpt_dbs, physical);
	  rdbg_printf (("[C Unremap L %ld R %ld ]", logical, physical));

	  after_image->bd_physical_page = after_image->bd_page;
	  TC (tc_cpt_unremap_dirty);
	}
    }
}


int
cpt_is_page_remapped (dp_addr_t page)
{
  DO_SET (index_tree_t *, it, &cpt_dbs->dbs_trees)
    {
      mutex_enter (&IT_DP_MAP (it, page)->itm_mtx);
      if (gethash (DP_ADDR2VOID (page), &IT_DP_MAP (it, page)->itm_remap))
	{
	  mutex_leave (&IT_DP_MAP (it, page)->itm_mtx);
	return 1;
    }
      mutex_leave (&IT_DP_MAP (it, page)->itm_mtx);
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
      mutex_enter (&IT_DP_MAP (it, dp)->itm_mtx);
      buf = (buffer_desc_t *) gethash (DP_ADDR2VOID (dp), &IT_DP_MAP (it, dp)->itm_dp_to_buf);
      mutex_leave (&IT_DP_MAP (it, dp)->itm_mtx);
      if (buf)
	{
	  uc_printf (("found l=%d in %s \n", buf->bd_page, it->it_key ? it->it_key->key_name 
		      : it == cpt_dbs->dbs_cpt_tree  ? "cpt_tree" : "unknown"));
	return buf;
    }
    }
  END_DO_SET();
  return NULL;
}


void
cpt_unremap_page_in_ram (const void *key, void *value)
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
  else
    uc_printf ((" refused unremap l=%d p=%d \n", logical, physical));
}


void
cpt_unremap_in_ram (void)
{
  /* if happens to be any buffers in RAM that are checkpoint
     remapped and not mapped back. Return number */
  maphash (cpt_unremap_page_in_ram, cpt_dbs->dbs_cpt_remap);
}


int mcp_batch;
int mcp_fill;
jmp_buf_splice mcp_next_batch;
dk_hash_t *remap;



remap_t *mcp_remaps;
remap_t **mcp_remap_ptrs;


void
cpt_mark_unremap (const void *key, void *value)
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



index_tree_t *
buf_belongs_to (buffer_desc_t * buf)
{
  /* will contain key and fragment identifier */
  return NULL;
}


void
cpt_place_buffers ()
{
  /* unremapped pages have been read into the dbs_cpt_tree.  Now place these into their correct trees 
   * Because finding the right tree is too hard, mark these simply as unallocated.  If these are left hanging the assert in it_cache_check will fail when the dp gets used for sth else */

  ptrlong dp;
  buffer_desc_t * buf;
  dk_hash_iterator_t hit;
  int inx;
  for (inx = 0; inx < IT_N_MAPS; inx++)
    {
      mutex_enter (&cpt_dbs->dbs_cpt_tree->it_maps[inx].itm_mtx);
      dk_hash_iterator (&hit, &cpt_dbs->dbs_cpt_tree->it_maps[inx].itm_dp_to_buf);
  while (dk_hit_next (&hit, (void **) &dp, (void**) &buf))
    {
      index_tree_t *it = buf_belongs_to (buf);
      if (it)
	{
	  /*dp_addr_t buf_dp = buf->bd_page;*/
	      GPF_T1 ("this is not implemented");
	}
      else
	{
	      if (buf->bd_is_write || buf->bd_readers)
		GPF_T1 ("buf in cpt tree not supposed to be occupied");
	      buf->bd_tree = NULL;
	      buf->bd_page = 0;
	      buf->bd_is_dirty = 0;
	  buf->bd_storage = NULL;
	}
	}
      clrhash (&cpt_dbs->dbs_cpt_tree->it_maps[inx].itm_dp_to_buf);
      mutex_leave (&cpt_dbs->dbs_cpt_tree->it_maps[inx].itm_mtx);
    }
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

  uc_printf (("Going to unremap %d old pages\n", mcp_fill));

  for (i = 0; i < mcp_fill; i++)
    {
      buffer_desc_t *buf;
	  mcp_itc->itc_page = 0;
	  mcp_itc->itc_tree = cpt_dbs->dbs_cpt_tree;
	  buf = dbs_buf_by_dp (cpt_dbs, mcp_remap_ptrs[i]->rm_logical);
	  if (!buf)
	{
	  ITC_IN_KNOWN_MAP (mcp_itc, mcp_remap_ptrs[i]->rm_logical);
	  page_wait_access (mcp_itc, mcp_remap_ptrs[i]->rm_logical, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
	  if (!buf || PF_OF_DELETED == buf)
	    {
	      log_error ("Reading deleted or occupied in cpt unremap L=%d", mcp_remap_ptrs[i]->rm_logical);
	    }
	  uc_printf ((" reading l=%d p=%d for unremap in cpt_tree\n", buf->bd_page, buf->bd_physical_page));
	  BD_SET_IS_WRITE (buf, -0);
	}
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
	  printf (" dp=%d is in backup set and is free\n", n);
	  GPF_T1 ("page in backup set and free");
	}
    }
#endif
}


void
cpt_uncommitted_dps (int clear)
{
  /* when a cpt is done with uncommitted data, the pages that are uncommitted are must not appear as taken in the allocation map saved by cpt.  So reset them and then put them back on. */
  DO_HT (ptrlong, dp, void *, d, cpt_uncommitted_remap_dp)
    {
      if (clear)
	dbs_free_disk_page (cpt_dbs, dp);
      else
	dbs_page_allocated (cpt_dbs, dp);
    }
  END_DO_HT;
  DO_HT (lock_trx_t *, lt, void *, d, cpt_uncommitted_lt)
    {
      if (lt->lt_dirty_blobs)
	{
	  DO_HT (void *, k, blob_layout_t *, bl, lt->lt_dirty_blobs)
	    {
	      /* for a blob that is uncommitted, do not record the pages as occupied in the cpt.  But do this only insofar there is a filled page dir.  And do not extend this beyond the first page of the page dir. 
	       * So there will be a possible leak of a few pages if roll fwd from the cpt, otherwise no leak. */
	      if (!bl->bl_it || bl->bl_it->it_storage != cpt_dbs)
		continue;
	      if (bl->bl_delete_later == BL_DELETE_AT_ROLLBACK)
		{
		  if (bl->bl_pages)
		    {
		      int inx;
		      for (inx= 0; inx < box_length ((caddr_t)bl->bl_pages) / sizeof (dp_addr_t); inx++)
			{
			  if (bl->bl_pages[inx])
			    {
			      if (clear)
				dbs_free_disk_page (cpt_dbs, bl->bl_pages[inx]);
			      else
				dbs_page_allocated (cpt_dbs, bl->bl_pages[inx]);
			    }
			}
		    }
		  if (bl->bl_dir_start)
		    {
		      if (clear)
			dbs_free_disk_page (cpt_dbs, bl->bl_dir_start);
		      else
			dbs_page_allocated (cpt_dbs, bl->bl_dir_start);
		    }
		}
	    }
	  END_DO_HT;
	}
    }
  END_DO_HT;
}


static void 
dbs_cpt_recov_obackup_reset (dbe_storage_t * dbs)
{
  buffer_desc_t * fs = dbs->dbs_free_set;
  buffer_desc_t * is = dbs->dbs_incbackup_set;
  dk_hash_iterator_t hit;
  void *dp, *remap_dp;

  memset (&bp_ctx, 0, sizeof (ol_backup_ctx_t));
  while (fs && is)
    {
      memcpy (is->bd_buffer + DP_DATA, fs->bd_buffer + DP_DATA, PAGE_DATA_SZ);
      page_set_checksum_init (is->bd_buffer + DP_DATA);
      fs = fs->bd_next;
      is = is->bd_next;
    }
  ol_write_registry (wi_inst.wi_master, NULL, ol_regist_unmark);
  dk_hash_iterator (&hit, dbs->dbs_cpt_remap);
  while (dk_hit_next (&hit, &dp, &remap_dp))
    dp_set_backup_flag (dbs, (dp_addr_t) (ptrlong) remap_dp, 0);

  /* cp remap pages will be ignored, so do not leave trash
     for dbs_count_pageset_items_2 */
  DO_SET (caddr_t, _page, &dbs->dbs_cp_remap_pages)
    {
      dp_set_backup_flag (dbs, (dp_addr_t)(ptrlong) _page, 0);
    }
  END_DO_SET();
  dbs_write_page_set (dbs, dbs->dbs_incbackup_set);
  dbs_write_cfg_page (dbs, 0);
}

void 
dbs_cpt_recov (void)
{
  int cpt_recov_file_complete = 0;
  int cpt_log_fd;
  dk_session_t * ses = dk_session_allocate (SESCLASS_TCPIP);
  long npages = 0, unpages = 0;
  int rc = 0, exit_after_recov = 0;
  char * new_name;

  dbs_cpt_recov_in_progress = 1;

  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
    {
      if (!dbs->dbs_cpt_file_name)
	continue;
      cpt_log_fd = fd_open (dbs->dbs_cpt_file_name, OPEN_FLAGS_RO);
      if (cpt_log_fd < 0) /* no cpt backup */
	continue;
      log_info ("Starting a database that was killed during checkpoint.  Recovering using checkpoint recov file.");
      LSEEK (cpt_log_fd, 0, SEEK_SET);
      tcpses_set_fd (ses->dks_session, cpt_log_fd);
      CATCH_READ_FAIL (ses)
	{
	  long stat = read_int (ses);
	  if (!DKSESSTAT_ISSET (ses, SST_OK))
	    goto err_end;
	  if (stat == 0)
	    {
	      log_error ("The checkpoint was stopped in the middle of making cpt recov file, recov file ignored");
	      goto err_end;
	    }
	  cpt_recov_file_complete = 1;
	  while (DKSESSTAT_ISSET (ses, SST_OK))
	    {
	      dp_addr_t logical;
	      caddr_t l = read_object (ses);
	      caddr_t obj = read_object (ses);
	      dtp_t dtp = DV_TYPE_OF (obj);
	      if (!DKSESSTAT_ISSET (ses, SST_OK))
		break;
	      logical = (dp_addr_t) unbox (l);
	      dk_free_box (l);
	      switch (dtp)
		{
		  case DV_LONG_INT:
			{
			  dp_addr_t physical = (dp_addr_t)(uptrlong)unbox (obj);

			  if (physical == DP_DELETED)
			    dbs_free_disk_page (dbs, logical);
			  else
			    {
			      cp_buf->bd_page = logical;
			      cp_buf->bd_physical_page = physical;
			      cp_buf->bd_storage = dbs;
			      buf_disk_read (cp_buf);
			      cp_buf->bd_physical_page = logical;
			      cp_buf->bd_is_dirty = 1;
			      buf_disk_write (cp_buf, logical);
			      cp_buf->bd_is_dirty = 0;
			      npages ++;
			      /*fprintf (stderr, "remap l=%d p=%d\n", logical, physical);*/
			      if (physical != logical)
				dbs_free_disk_page (dbs, physical);
			      /*remhash (DP_ADDR2VOID (logical), dbs->dbs_cpt_remap);*/
			    }
			  break;
			}
		  case DV_STRING:
			{
			  memcpy (cp_buf->bd_buffer, obj, PAGE_SZ);
			  cp_buf->bd_page = logical;
			  cp_buf->bd_physical_page = logical;
			  cp_buf->bd_storage = dbs;
			  /*fprintf (stderr, "**remap l=%d\n", logical);*/
			  cp_buf->bd_is_dirty = 1;
			  buf_disk_write (cp_buf, logical);
			  cp_buf->bd_is_dirty = 0;
			  unpages ++;
			  break;
			}
		  default:
			{
			  log_error ("Unknown object in checkpoint recovery file");
			  dk_free_tree (obj);
			  goto err_end;
			}
		}
	      dk_free_box (obj);
	    }
	err_end:
	  session_flush_1 (ses);
	}
      FAILED 
	{
	}
      END_READ_FAIL (ses);
      fd_close (cpt_log_fd, dbs->dbs_cpt_file_name);
      new_name = setext (dbs->dbs_cpt_file_name, "cpt-after-recov", EXT_SET);
      log_info ("Moving %s to %s for future reference.", dbs->dbs_cpt_file_name, new_name);
      rc = rename (dbs->dbs_cpt_file_name, new_name);
      if (0 != rc)
        {
	  exit_after_recov = 1;
	}	  
      if (cpt_recov_file_complete && dbs->dbs_log_name)
	{
	  new_name = setext (dbs->dbs_log_name, "trx-after-recov", EXT_SET);
	  log_info ("Database recovery done from checkpoint recovery file, hence ignoring transaction log %s.", dbs->dbs_log_name);
	  log_info ("Moving %s to %s for future reference.", dbs->dbs_log_name, new_name);
          rc = rename (dbs->dbs_log_name, new_name);
	  if (0 != rc)
	    {
	      exit_after_recov = 1;
	    }	  
	}
      if (!cpt_recov_file_complete)
	log_error ("The checkpoint recov file was not complete, hence will roll forward from log.");
      if (npages || unpages)
	{
	  clrhash (dbs->dbs_cpt_remap);
	  dk_set_free (dbs->dbs_cp_remap_pages);
	  dbs->dbs_cp_remap_pages = NULL;
	  dbs_cpt_recov_obackup_reset (dbs); /* this write the cfg page also */
	  dbs_sync_disks (dbs);
	  log_info ("%ld pages processed based on checkpoint recov file, %ld had uncommitted data at time of checkpoint.", npages, unpages);
	}
    }
  END_DO_SET();
  PrpcSessionFree (ses);
  if (exit_after_recov)
    {
      log_error ("The cpt backup file or transaction log file cannot be renamed, must do this manually, exiting.");
      call_exit (-1);
    }
  dbs_cpt_recov_in_progress = 0;
}

void 
dbs_cpt_backup (void)
{
  int second_round = 0;
  dk_set_t rem;
  int inx;
  int cpt_log_fd;
  dk_session_t * ses = dk_session_allocate (SESCLASS_TCPIP);
 retry:
  cpt_new_pages = NULL;
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
    {
      dk_hash_t * cpt_bkp;
      if (!dbs->dbs_cpt_file_name)
	continue;
      cpt_bkp = hash_table_allocate (101);
      cpt_log_fd = fd_open (dbs->dbs_cpt_file_name, OPEN_FLAGS);  
      ftruncate (cpt_log_fd, 0);
      LSEEK (cpt_log_fd, 0, SEEK_SET);
      tcpses_set_fd (ses->dks_session, cpt_log_fd);

      CATCH_WRITE_FAIL (ses)
	{
	  print_int (0, ses);
	  session_flush_1 (ses);
	}
      END_WRITE_FAIL (ses);
      cpt_uncommitted_remap = hash_table_allocate (101);
      cpt_uncommitted_lt = hash_table_allocate (11);
      cpt_uncommitted_remap_dp = hash_table_allocate (101); 
      DO_SET (index_tree_t *, it, &dbs->dbs_trees)
	{
	  int rc;
	  mcp_itc->itc_thread = THREAD_CURRENT_THREAD;
	  itc_from_it (mcp_itc, it);
	  it_from_g = it;
	  for (inx = 0; inx < IT_N_MAPS; inx++)
	    {
	      mutex_enter (&it->it_maps[inx].itm_mtx);
	      rc = cpt_uncommitted_backup (it, inx, ses, cpt_bkp);
	      mutex_leave (&it->it_maps[inx].itm_mtx);
	      if (CPT_RB_NO_DISK  == rc && !second_round)
		{
		  second_round = 1;
		  log_error ("checkpoint ran out of disk space for rb of uncommitted.  Server exiting without starting the checkpoint.  Upon restart will recover from roll forward log.  More disk space should be made available");
		  ftruncate (cpt_log_fd, 0);
		  fd_close (cpt_log_fd, dbs->dbs_cpt_file_name);
		  unlink (dbs->dbs_cpt_file_name);
		  call_exit (-1);
		  cpt_out_of_disk ();
		  goto retry;
		}
	    }
	}
      END_DO_SET();
      DO_SET (index_tree_t *, it, &dbs->dbs_trees)
	{
	  for (inx = 0; inx < IT_N_MAPS; inx++)
	    {
	      mutex_enter (&it->it_maps[inx].itm_mtx);
	      DO_HT (void *, k, void *, d, &it->it_maps[inx].itm_remap)
		{
		  dp_addr_t logical = (dp_addr_t)(uptrlong) k;
		  dp_addr_t physical = (dp_addr_t)(uptrlong) d;
		  if (gethash (DP_ADDR2VOID(logical), cpt_bkp))
		    {
		      /*fprintf (stderr, "already in backup %d, phys=%d\n", logical, physical);*/
		      continue;
		    }
		  CATCH_WRITE_FAIL (ses)
		    {
		      print_int (logical, ses);
		      print_int (physical, ses);
		    }
		  END_WRITE_FAIL (ses);
		  sethash (DP_ADDR2VOID (logical),  cpt_bkp, DP_ADDR2VOID (physical));
		}
	      END_DO_HT;
	      mutex_leave (&it->it_maps[inx].itm_mtx);
	    }
	}
      END_DO_SET();
      DO_HT (void *, k, void *, d, dbs->dbs_cpt_remap)
	{
	  dp_addr_t logical = (dp_addr_t)(uptrlong) k;
	  dp_addr_t physical = (dp_addr_t)(uptrlong) d;
	  dp_addr_t prev;
	  if (0 != (prev = (dp_addr_t)(uptrlong)gethash (DP_ADDR2VOID(logical), cpt_bkp)))
	    {
	      /*fprintf (stderr, "already in backup set %d, phys=%d, prev phys=%d\n", logical, physical, prev);*/
	      continue;
	    }
	  CATCH_WRITE_FAIL (ses)
	    {
	      print_int (logical, ses);
	      print_int (physical, ses);
	    }
	  END_WRITE_FAIL (ses);
	}
      END_DO_HT;
      session_flush (ses);
      if (dbs_stop_cp == 2)
	{
	  call_exit (-1);
	}


      sch_save_roots (wi_inst.wi_schema);
      if (LTE_OK != dbs_write_registry (dbs))
	{
	  log_error ("Since registry could not be written, checkpoint not started.  Server exiting.  Make more disk space available and restart, which will roll forward from log.");
	  call_exit (-1);
	}
      dbs_write_page_set (dbs, dbs->dbs_free_set);
      dbs_write_page_set (dbs, dbs->dbs_incbackup_set);
      rem = dbs->dbs_cp_remap_pages;
      dbs->dbs_cp_remap_pages = NULL;
      dbs_write_cfg_page (dbs, 0);
      dbs->dbs_cp_remap_pages = rem;
      LSEEK (cpt_log_fd, 0, SEEK_SET);
      CATCH_WRITE_FAIL (ses)
	{
	  print_int (1, ses);
	  session_flush_1 (ses);
	}
      END_WRITE_FAIL (ses);
      fsync (cpt_log_fd);
      fd_close (cpt_log_fd, dbs->dbs_cpt_file_name);
      dbs_sync_disks (dbs);
      hash_table_free (cpt_uncommitted_remap);
      hash_table_free (cpt_uncommitted_lt);
      hash_table_free (cpt_uncommitted_remap_dp);
      cpt_uncommitted_remap = NULL;
      cpt_uncommitted_lt = NULL;
      cpt_uncommitted_remap_dp = NULL;
      hash_table_free (cpt_bkp);
    }
  END_DO_SET();
  PrpcSessionFree (ses);
}

int dbs_stop_cp = 0;

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
  LEAVE_TXN;
  wi_check_all_compact (0);
  DO_BOX (buffer_pool_t *, bp, inx, wi_inst.wi_bps)
    {
      IN_BP (bp);
      mt_write_dirty (bp, 0, 0 /*PHYS_EQ_LOG*/ );
      LEAVE_BP (bp);
    }
  END_DO_BOX;
  if (!shutdown)
    {
  iq_shutdown (IQ_SYNC);

  DO_BOX (buffer_pool_t *, bp, inx, wi_inst.wi_bps)
    {
      IN_BP (bp);
      mt_write_dirty (bp, 0, 0 /*PHYS_EQ_LOG*/ );
      LEAVE_BP (bp);
    }
  END_DO_BOX;
  iq_shutdown (IQ_SYNC);
    }
    
  IN_TXN;
  cpt_rollback (LT_KILL_FREEZE);
  iq_shutdown (IQ_STOP);
  wi_check_all_compact (0);
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
      start_atomic = get_msec_real_time ();

      /* sync */
    mcp_itc = itc_create (NULL, NULL);
      wi_write_dirty ();
      dbs_sync_disks (dbs);
      dbs_cpt_backup ();
      if (dbs_stop_cp == 1)
	{
	  call_exit (-1);
	}
      if (dbs_stop_cp == 4)
        virtuoso_sleep (60, 0);

    rdbg_printf (("\nCheckpoint atomic.\n"));
    sch_save_roots (wi_inst.wi_schema);
    dbs_write_registry (dbs);
    DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
      {
	index_tree_t *del_it;
	cpt_dbs = dbs;
	remap = dbs->dbs_cpt_remap;
	cpt_uncommitted_remap = hash_table_allocate (101);
	cpt_uncommitted_lt = hash_table_allocate (11);
	cpt_uncommitted_remap_dp = hash_table_allocate (101); 
	DO_SET (index_tree_t *, it, &dbs->dbs_trees)
	  {
	    void *k, *d;
	    dk_hash_iterator_t hit;
	    mcp_itc->itc_thread = THREAD_CURRENT_THREAD;
	    itc_from_it (mcp_itc, it);
	    it_from_g = it;
	    for (inx = 0; inx < IT_N_MAPS; inx++)
	      {
	    rdbg_printf (("%s %ld\n",
		  it->it_key ? it->it_key->key_name : "no key",
			      (long) it->it_maps[inx].itm_remap.ht_count));

		mutex_enter (&it->it_maps[inx].itm_mtx);
		cpt_uncommitted (it, inx);
		maphash (cpt_neodisk_page, &it->it_maps[inx].itm_remap);
		clrhash (&it->it_maps[inx].itm_remap);
		dk_hash_iterator (&hit, cpt_uncommitted_remap);
		while (dk_hit_next (&hit, &k, &d))
		  {
		    uc_printf ((" uncommitted in %s:%d l=%ld p=%ld cptremap=%ld \n",
			       it->it_key->key_name, inx, (ptrlong)k, (ptrlong)d, (ptrlong)
			       gethash (k, cpt_dbs->dbs_cpt_remap)));
		    sethash (k, &it->it_maps[inx].itm_remap, d);
	  }
		clrhash (cpt_uncommitted_remap);
		mutex_leave (&it->it_maps[inx].itm_mtx);
	      }
	  }
	END_DO_SET();
	hash_table_free (cpt_uncommitted_remap);
	cpt_uncommitted_remap = NULL;
	wi_write_dirty ();

	while (NULL != (del_it = (index_tree_t *) dk_set_pop (&dbs->dbs_deleted_trees)))
	  {
	    int inx;
	    mcp_itc->itc_thread = THREAD_CURRENT_THREAD;
	    it_from_g = del_it;
	    for (inx = 0; inx < IT_N_MAPS; inx++)
	      {
		mutex_enter (&del_it->it_maps[inx].itm_mtx);
		  maphash (cpt_neodisk_page, &del_it->it_maps[inx].itm_remap);
		clrhash (&del_it->it_maps[inx].itm_remap);
		mutex_leave (&del_it->it_maps[inx].itm_mtx);
	  }
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
	cpt_uncommitted_dps (1);
	dbs_write_page_set (dbs, dbs->dbs_free_set);
	cpt_uncommitted_dps (0);
	dbs_write_page_set (dbs, dbs->dbs_incbackup_set);
	dbs_write_cfg_page (dbs, 0);
	hash_table_free (cpt_uncommitted_lt);
	hash_table_free (cpt_uncommitted_remap_dp);
	IN_DBS (dbs);
	LEAVE_DBS (dbs);
	if (DBS_PRIMARY == dbs->dbs_type)
	  log_checkpoint (dbs, log_name, shutdown);
      }
    END_DO_SET();
    mcp_itc->itc_itm1 = NULL;
    itc_free (mcp_itc);
    mcp_itc = NULL;
    uc_printf (("Checkpoint made. %d delta pages.\n", mcp_delta_count));

    dk_free ((caddr_t) mcp_remaps, mcp_batch * sizeof (remap_t));
    dk_free ((caddr_t) mcp_remap_ptrs, mcp_batch * sizeof (caddr_t));
    unlink(CHECKPOINT_IN_PROGRESS_FILE);
      DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
	{
	  if (!dbs->dbs_cpt_file_name)
	    continue;
	  unlink (dbs->dbs_cpt_file_name); /* remove cpt backup file */
	}
      END_DO_SET();
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
      if (lt_has_locks (qi->qi_trx))
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
