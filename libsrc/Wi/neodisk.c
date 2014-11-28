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
 *  Copyright (C) 1998-2014 OpenLink Software
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
#include "srvstat.h"
#include "recovery.h"
#include "sqlbif.h"
#include "datesupp.h"


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

extern long tc_atomic_wait_2pc;
extern int32 enable_flush_all;
extern long tc_n_flush;
long atomic_cp_msecs;
long tc_dirty_at_cpt_start;
sys_timer_t sti_cpt_atomic;
sys_timer_t sti_cpt_sync;
sys_timer_t sti_cpt_rollback;
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
it_free_remap (index_tree_t * it, dp_addr_t logical, dp_addr_t remap, int dp_flags, oid_t col_id)
{
  /* Free the remap page of logical.  */
  it_map_t * itm = IT_DP_MAP (it, logical);
  ASSERT_IN_MTX (&itm->itm_mtx);
  if (!remap)
    remap = (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (logical), &itm->itm_remap);
  if (remap != logical)
    {
      extent_map_t * em = IT_COL_REMAP_EM (it, col_id);
      em_free_dp (em, remap, EXT_REMAP);
    }
  else
    {
      /* log == phys. Free is OK if not remapped in checkpoint */
      if (!DP_CHECKPOINT_REMAP (it->it_storage, logical))
	{
	  em_free_dp (IT_COL_EM (it, col_id), logical, (dp_flags == DPF_INDEX || dp_flags == DPF_HASH || dp_flags == DPF_COLUMN) ? EXT_INDEX : EXT_BLOB);
	}
    }
}


index_tree_t *it_from_g;
long busy_pre_image_scrap;




int32  cp_is_over = 0;
#ifdef CHECKPOINT_TIMING
long start_killing = 0, all_trx_killed = 0, cp_is_attomic = 0;
#endif

void
lt_rb_check (lock_trx_t * lt)
{
  return;
  DO_HT (ptrlong, k, rb_entry_t *, rbe, lt->lt_rb_hash)
    {
      rb_entry_t * rbe2 = rbe;
      for (rbe2 = rbe; rbe2; rbe2 = rbe2->rbe_next)
	{
	  if (0 != IE_ROW_VERSION (rbe2->rbe_string + rbe2->rbe_row))
	    GPF_T1 ("corrupt rbe in cpt");
	}
    }
  END_DO_HT;
}

int enable_cpt_rb_ck = 0;

void
cpt_rb_ck ()
{
  DO_SET (volatile lock_trx_t *, lt, &all_trxs)
    {
      if (lt->lt_threads && lt->lt_thr && !lt->lt_vdb_threads)
	{
	  du_thread_t * thr = lt->lt_thr;
	  if (thr->thr_sem->sem_entry_count || !thr->thr_sem->sem_waiting.thq_count  || thr != thr->thr_sem->sem_waiting.thq_head.thr_prev)
	    log_info ("thread %x may not be stopped for cpt rb lt %p", thr, lt);
	}
    }
  END_DO_SET();
}
du_thread_t * cpt_thread;

void
cpt_rollback (int may_freeze)
{
#ifdef CHECKPOINT_TIMING
  start_killing = get_msec_real_time();
#endif
  wi_inst.wi_is_checkpoint_pending = LT_KILL_FREEZE == may_freeze ? CPT_CHECKPOINT : CPT_ATOMIC_PENDING;
  cpt_thread = THREAD_CURRENT_THREAD;
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
	case LT_BLOWN_OFF_C:
	case LT_CLOSING:
	case LT_COMMITTED:
#ifdef VIRTTP
	  if (stat == LT_COMMITTED && lt->lt_2pc._2pc_wait_commit)
	    break;
#endif
	  rdbg_printf (("trx %lx killed by checkpoint while closing\n", lt));
	  lt_kill_other_trx (lt, NULL, NULL, may_freeze);
	  if (lt->lt_threads)
	    goto next;
	  break;
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

	case LT_CL_PREPARED:
	  if (CPT_ATOMIC_PENDING == wi_inst.wi_is_checkpoint_pending && !wi_inst.wi_atomic_ignore_2pc)
	    {
	      TC (tc_atomic_wait_2pc);
	      lt_wait_until_dead (lt);
	      goto next;
	    }
	  if (lt->lt_threads)
	    {
	      lt_wait_until_dead (lt);
	      goto next;
	    }
	  break;
	case LT_1PC_PENDING:
	case LT_2PC_PENDING:
	case LT_PREPARE_PENDING:
	  if (CPT_ATOMIC_PENDING == wi_inst.wi_is_checkpoint_pending)
	    {
	      TC (tc_atomic_wait_2pc);
	      lt_wait_until_dead (lt);
	      goto next;
	    }
	  /* this is a state of wait for reply, will not resume the 2pc until cpt is done */
	  break;
	default:  GPF_T1 ("Unexpected lt_status in cpt_rollback");
	}
    }
  END_DO_SET();
  if (CPT_ATOMIC_PENDING == wi_inst.wi_is_checkpoint_pending)
    wi_inst.wi_is_checkpoint_pending = CPT_ATOMIC;
#ifdef CHECKPOINT_TIMING
  all_trx_killed = get_msec_real_time();
#endif
  if (enable_cpt_rb_ck)
    cpt_rb_ck ();
  ASSERT_IN_TXN;
#ifdef CHECKPOINT_TIMING
  cp_is_attomic = get_msec_real_time();
#endif
  rdbg_printf (("Checkpoint atomic\n"));
}


server_lock_t server_lock;


void
lt_wait_checkpoint_1 (int cl_listener_also)
{
  du_thread_t * self = THREAD_CURRENT_THREAD;
  ASSERT_IN_TXN;
  if (self == server_lock.sl_owner
      )
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
      if (self->thr_lt)
	break;
    }
}


void
lt_wait_checkpoint (void)
{
  lt_wait_checkpoint_1 (0);
}


void
lt_wait_checkpoint_lt (lock_trx_t * lt)
{
  if (LT_NEED_WAIT_CPT (lt))
    lt_wait_checkpoint_1 (0);
}

void
cpt_over (void)
{
  ASSERT_IN_TXN;
  wi_inst.wi_checkpoint_atomic = 0;
  wi_inst.wi_is_checkpoint_pending = 0;
  cpt_thread = NULL;
  DO_SET (du_thread_t *, thr, &wi_inst.wi_waiting_checkpoint)
  {
    if (thr->thr_lt)
      {
	lock_trx_t * lt = thr->thr_lt;
	if (LT_FREEZE == lt->lt_status)
	  {
	    lt->lt_close_ack_threads = 0;
	    lt->lt_status = LT_PENDING;
	  }
      }
    semaphore_leave (thr->thr_sem);
  }
  END_DO_SET();
  dk_set_free (wi_inst.wi_waiting_checkpoint);
  wi_inst.wi_waiting_checkpoint = NULL;
  cp_is_over = get_msec_real_time();
}

int32 cpt_remap_recovery = 0;

void
dbs_read_checkpoint_remap (dbe_storage_t * dbs, dp_addr_t from)
{
  cp_buf->bd_storage = dbs;
  while (from)
    {
      int inx;
      if (cpt_remap_recovery && -1 != dk_set_position (dbs->dbs_cp_remap_pages, DP_ADDR2VOID (from)))
	{
	  log_error ("duplicate cpt remap page L=%d", from);
	  return;
	}
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
  memset (cp_buf->bd_buffer + DP_DATA, 0, PAGE_DATA_SZ);
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
	  page = em_new_dp (dbs->dbs_extent_map, EXT_INDEX, 0, NULL);
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
	  memset (cp_buf->bd_buffer + DP_DATA, 0, PAGE_DATA_SZ);
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

it_cursor_t *mcp_itc;

long tc_cpt_unremap_dirty;




typedef struct uc_insert_s
{
  it_cursor_t *	uci_registered;
  row_lock_t *	uci_rl;
  db_buf_t	uci_row;
  dbe_key_t *	uci_key;
  struct uc_insert_s *	uci_next;
  slice_id_t 	uci_slice;
} uc_insert_t;


void
rl_add_cpt_wait (row_lock_t * rl, it_cursor_t * wait)
{
  it_cursor_t ** prev = &rl->pl_waiting;
  wait->itc_next_on_lock = NULL;
  while (*prev)
    prev = &(*prev)->itc_next_on_lock;
  *prev = wait;
}


void
lt_note (char * file, int line)
{
  log_error ("cpt/lt unusual cond %s:%d", file, line);
}


int cpt_init_trx_rc_fill;
int cpt_trx_rc_n_ck = 0;


void
cpt_trx_rc_ck ()
{
  int inx;
  cpt_trx_rc_n_ck++;
  for (inx = 0; inx < trx_rc->rc_fill; inx++)
    {
      lock_trx_t * lt = (lock_trx_t*) trx_rc->rc_items[inx];
      if (lt->lt_lock.ht_count)
	lt_weird ();
    }
}


void
page_lock_to_row_locks (buffer_desc_t * buf)
{
  /* each row gets its own lock owned by the pl excl owner.  Waits are divided.  An itc at end will wait for the first rl but be marked at end.  */
  it_cursor_t * waiting;
  page_lock_t * pl = buf->bd_pl;
  pl->pl_type &= ~PL_PAGE_LOCK;
  DO_ROWS (buf, map_pos, row, NULL)
    {
      row_lock_t * rl = rl_allocate ();
      rl->rl_next = PL_RLS (pl, map_pos);
      PL_RLS (pl, map_pos) = rl;
      rl->pl_type = PL_EXCLUSIVE | RL_FOLLOW;
      rl->pl_owner = pl->pl_owner;
      rl->rl_pos = map_pos;
      pl->pl_n_row_locks++;
    }
  END_DO_ROWS;
  waiting = pl->pl_waiting;
  while (waiting)
    {
      it_cursor_t * next = waiting->itc_next_on_lock;
      int pos = waiting->itc_map_pos;
      row_lock_t * rl;
      if (ITC_AT_END == pos)
	pos = 0;
      rl = pl_row_lock_at (pl, pos);
      rl_add_cpt_wait (rl, waiting);
      waiting = next;
    }
  pl->pl_waiting = NULL;
  cpt_trx_rc_ck ();
}


row_lock_t *
pl_remove_rl_at (page_lock_t * pl, int pos)
{
  row_lock_t ** prev = &PL_RLS(pl, pos);
  row_lock_t * rl = *prev;
  while (rl)
    {
      if (rl->rl_pos == pos)
	{
	  *prev = rl->rl_next;
	  return rl;
	}
      prev = &rl->rl_next;
      rl = rl->rl_next;
    }
  GPF_T1 ("supposed to have a rl for ins after img in cpt rb");
  return NULL;
}


uc_insert_t * cpt_uci_list;
uc_insert_t * cpt_last_uci;


void
buf_extract_registered (buffer_desc_t * buf, int map_pos, int col_row, it_cursor_t ** reg_ret)
{
  it_cursor_t * registered = buf->bd_registered;
  it_cursor_t ** prev = &buf->bd_registered;
  while (registered)
    {
      it_cursor_t * next = registered->itc_next_on_page;
      if (registered->itc_map_pos == map_pos && (-1 == col_row || col_row == registered->itc_col_row))
	{
	  *prev = registered->itc_next_on_page;
	  registered->itc_next_on_page = *reg_ret;
	  *reg_ret = registered;
	}
      else
	{
	  *prev = registered;
	  prev = &registered->itc_next_on_page;
	}
      registered = next;
    }
}


void
cpt_ins_image (buffer_desc_t * buf, int map_pos)
{
  rb_entry_t * rbe;
  NEW_VARZ (uc_insert_t, uci);
  mutex_enter (&wi_inst.wi_cpt_lt->lt_rb_mtx);
  lt_rb_new_entry (wi_inst.wi_cpt_lt, -1, NULL, buf, BUF_ROW (buf, map_pos), RB_UPDATE);
  rbe = (rb_entry_t *) gethash ((void*)(ptrlong)(uint32)-1, wi_inst.wi_cpt_lt->lt_rb_hash);
  if (rbe->rbe_next) GPF_T1 ("uncommitted insert rbe entry can't have a next");
  if (0 != IE_ROW_VERSION (rbe->rbe_string + rbe->rbe_row)) GPF_T1 ("insert rb entry bad from the start");
  remhash ((void*)(ptrlong)(uint32)-1, wi_inst.wi_cpt_lt->lt_rb_hash);
  mutex_leave (&wi_inst.wi_cpt_lt->lt_rb_mtx);
  uci->uci_row = rbe->rbe_string + rbe->rbe_row;
  uci->uci_key = buf->bd_tree->it_key;
  uci->uci_slice = buf->bd_tree->it_slice;
  if (!uci->uci_key->key_versions[IE_KEY_VERSION (uci->uci_row)])
    GPF_T1 ("bad key version in insert rb image in cpt");
  if (!cpt_last_uci)
    {
      cpt_uci_list = cpt_last_uci = uci;
    }
  else
    {
      cpt_last_uci->uci_next = uci;
      cpt_last_uci = uci;
    }
  uci->uci_rl = pl_remove_rl_at (buf->bd_pl, map_pos);
  buf_extract_registered (buf, map_pos, -1, &uci->uci_registered);
  dk_free ((caddr_t)rbe, sizeof (rb_entry_t));
  lt_rb_check (wi_inst.wi_cpt_lt);
}


void
cpt_upd_image (buffer_desc_t * buf, int map_pos)
{
  lt_rb_update (wi_inst.wi_cpt_lt, buf, BUF_ROW (buf, map_pos));
  lt_rb_check (wi_inst.wi_cpt_lt);
}


void
cpt_reinsert_uci (uc_insert_t * uci, it_cursor_t * itc)
{
  /* insert a rolled back insert.  Make a pl and insert the rl under it and set the registrations of waiting etc. */
  rb_entry_t rbe;
  int res, inx, old_lt_status;
  buffer_desc_t * buf;
  LOCAL_RD (rd);
  rbe.rbe_row = 0;
  rbe.rbe_string = uci->uci_row;
  rbe.rbe_key_id = uci->uci_key->key_id;
  rbe_page_row (&rbe, &rd);
  rd.rd_op = RD_INSERT;
  old_lt_status = uci->uci_rl->pl_owner->lt_status;
  uci->uci_rl->pl_owner->lt_status = LT_PENDING;
  ITC_INIT (itc, NULL, uci->uci_rl->pl_owner);
  itc_from (itc, uci->uci_key, uci->uci_slice);
  itc->itc_insert_key = rd.rd_key;
  itc->itc_search_mode = SM_INSERT;
  if (rd.rd_key->key_is_geo)
    {
      rd.rd_keep_together_itcs = uci->uci_registered;
      rd.rd_rl = uci->uci_rl;
      ITC_FAIL (itc)
	{
	  buf = itc_reset (itc);
	  itc_geo_insert (itc, buf, &rd);
	}
      ITC_FAILED
	{
	  goto after_fail;
	}
      END_FAIL(itc);
after_fail:
      uci->uci_rl->pl_owner->lt_status = old_lt_status;
      rd_free (&rd);
      return;
    }
  itc->itc_key_spec = rd.rd_key->key_insert_spec;
  for (inx = 0; inx < rd.rd_key->key_n_significant; inx++)
    itc->itc_search_params[inx] = rd.rd_values[rd.rd_key->key_part_in_layout_order[inx]];
  ITC_FAIL (itc)
    {
  buf = itc_reset (itc);
  res = itc_search (itc, &buf);
  if (BUF_NEEDS_DELTA (buf))
    {
      ITC_IN_KNOWN_MAP (itc, itc->itc_page);
      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (itc);
    }
  rd.rd_rl = uci->uci_rl;
  /* this will not escalate locks because the rl is given explicitly */
  if (DVC_LESS == res)
    itc_skip_entry (itc, buf);
  else if (DVC_MATCH == res)
    {
      log_error ("suspect non-unq insert in replay of cpt rb");
      itc_page_leave (itc, buf);
	  goto cleanup;
    }
    }
  ITC_FAILED
    {
      goto cleanup;
    }
  END_FAIL (itc);
  rd.rd_keep_together_itcs = uci->uci_registered;
  itc_insert_dv (itc, &buf, &rd, 0, uci->uci_rl);
cleanup:
  uci->uci_rl->pl_owner->lt_status = old_lt_status;
  rd_free (&rd);
}


int
lt_all_visited (lock_trx_t * lt, dk_hash_t * visited)
{
  IN_LT_LOCKS (lt);
  DO_HT (page_lock_t *, pl, void *, ignore, &lt->lt_lock)
    {
      if (!gethash ((void*)pl, visited))
	{
	  LEAVE_LT_LOCKS (lt);
	  return 0;
	}
    }
  END_DO_HT;
  LEAVE_LT_LOCKS (lt);
  return 1;
}


void
pl_cpt_rollback_page (page_lock_t * pl, it_cursor_t * itc)
{
  dk_set_t rd_list = NULL;
  row_delta_t ** rds;
  lock_trx_t *lt = itc->itc_ltrx;
  buffer_desc_t *buf = NULL;

  if (DP_DELETED == pl->pl_page)
    {
      TC (tc_release_pl_on_deleted_dp);
      return;
    }
  ITC_IN_KNOWN_MAP (itc, pl->pl_page);
  page_wait_access (itc, pl->pl_page, NULL, &buf, PA_WRITE, RWG_WAIT_KEY);
  if (PF_OF_DELETED == buf)
    {
      /* check needed here because the page could have gone out during the above wait and the wait itself could give 'a no wait status with bad timing  The page map does not serialize the whole delete as atomic. */
      TC (tc_release_pl_on_deleted_dp);
      ITC_LEAVE_MAPS (itc);
      return;
    }

  itc->itc_page = pl->pl_page;
  if (itc->itc_insert_key->key_is_col)
    {
      pl_cpt_col_page (pl, itc, buf, 0);
      return;
    }
  if (PL_IS_PAGE (pl))
    {
      DO_ROWS (buf, map_pos, row, NULL)
	{
	  itc_rollback_row (itc, &buf, map_pos, NULL, pl, &rd_list);
	}
	END_DO_ROWS;
    }
  else
    {
      DO_RLOCK (rl, pl)
      {
	if (rl->pl_owner == lt)
	  {
	    itc_rollback_row (itc, &buf, rl->rl_pos, rl, pl, &rd_list);
	  }
      }
      END_DO_RLOCK;
    }
  if (!rd_list)
    {
      page_leave_outside_map (buf);
      return;
    }
  rds = (row_delta_t **) list_to_array (dk_set_nreverse (rd_list));
  if (!PL_IS_PAGE (pl))
    buf_sort ((buffer_desc_t **) rds, BOX_ELEMENTS (rds), (sort_key_func_t) rd_pos_key);
  page_apply (itc, buf, BOX_ELEMENTS (rds), rds, PA_MODIFY);
  rd_list_free (rds);
}


dk_set_t
lt_list_unvisited (lock_trx_t * lt, dk_hash_t * visited)
{
  int n = 0;
  dk_set_t res = NULL;
  IN_LT_LOCKS (lt);
  DO_HT (page_lock_t *, pl, void*, ignore, &lt->lt_lock)
    {
      if (!gethash ((void*)pl, visited))
	{
	  dk_set_push (&res, (void*)pl);
	  if (++n > 10000)
	    break;
	}
    }
  END_DO_HT;
  LEAVE_LT_LOCKS (lt);
  return res;
}


void
cpt_lt_rollback (lock_trx_t * lt)
{
  dk_hash_t * visited = hash_table_allocate (101);
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  ITC_INIT (itc, NULL, lt);
  do
    {
      dk_set_t locks = lt_list_unvisited (lt, visited);
      DO_SET (page_lock_t *, pl, &locks)
	{
	  itc->itc_tree = pl->pl_it;
	  itc->itc_insert_key = itc->itc_tree->it_key;
	  sethash ((void*)pl, visited, (void*) 1);
	  pl_cpt_rollback_page (pl, itc);
	  cpt_trx_rc_ck ();
	  lt_rb_check (wi_inst.wi_cpt_lt);
	  ITC_LEAVE_MAPS (itc);
	}
      END_DO_SET ();
      dk_set_free (locks);
    } while (!lt_all_visited (lt, visited));
  hash_table_free (visited);
}

void
cpt_uncommitted ()
{
  cpt_init_trx_rc_fill = trx_rc->rc_fill;
  cpt_trx_rc_n_ck = 0;
  cpt_trx_rc_ck ();
  if (!wi_inst.wi_cpt_lt)
    {
      wi_inst.wi_cpt_lt = lt_allocate ();
      dk_set_delete (&all_trxs, (void*)wi_inst.wi_cpt_lt);
      wi_inst.wi_cpt_lt->lt_client = bootstrap_cli;
      wi_inst.wi_cpt_lt->lt_status = LT_PENDING;
    }
  lt_rb_check (wi_inst.wi_cpt_lt);
  cpt_uci_list = NULL;
  cpt_last_uci = NULL;
  cpt_col_uncommitted (wi_inst.wi_master);
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (lt->lt_rb_page)
	lt_rb_check (lt);
    }
  END_DO_SET();
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (lt->lt_rb_page)
	cpt_lt_rollback (lt);
    }
  END_DO_SET();
}


int
it_all_locks_visited (index_tree_t * it, dk_hash_t * visited)
{
  int inx;
  for (inx = 0; inx < IT_N_MAPS; inx++)
    {
      dk_mutex_t * itm_mtx = &it->it_maps[inx].itm_mtx;
      mutex_enter (itm_mtx);
      DO_HT (ptrlong, dp, page_lock_t *, pl, &it->it_maps[inx].itm_locks)
	{
	  if (!gethash ((void*)pl, visited))
	    {
	      mutex_leave (itm_mtx);
	      return 0;
	    }
	}
      END_DO_HT;
      mutex_leave (itm_mtx);
    }
  return 1;
}

void
cpt_restore_row (buffer_desc_t * buf, int pos, dk_set_t * rd_list)
{
  key_ver_t kv;
  db_buf_t row;
  if (ITC_AT_END == pos)
    {
      TC (tc_deld_row_rl_rb);
      return;
    }
  row = BUF_ROW (buf, pos);
  kv = IE_KEY_VERSION (row);
  if (KV_LEAF_PTR != kv)
    {
      rb_entry_t *rbe = lt_rb_entry (&wi_inst.wi_cpt_lt, buf, row, NULL, NULL, LT_RB_LEAVE_MTX | LT_RB_ONLY_OWN);
      if (!rbe)
	return;
      {
	  NEW_VARZ (row_delta_t, rd);
	  rd->rd_allocated = RD_ALLOCATED;
	  rbe_page_row (rbe, rd);
	  rd->rd_map_pos = pos;
	  rd->rd_op = RD_UPDATE;
	  rd->rd_keep_together_dp = buf->bd_page;
	  rd->rd_keep_together_pos = pos;
	  dk_set_push (rd_list, (void*) rd);
	}
    }
}


void
cpt_pl_restore (page_lock_t * pl, it_cursor_t * itc)
{
  /* take the after image from the rb state of wi_cpt_lt to put the uncommitted state back */
  buffer_desc_t * buf;
  dk_set_t rd_list = NULL;
  row_delta_t ** rds;
  if (PL_IS_PAGE (pl))
    return;
  if (DP_DELETED == pl->pl_page)
    return;
  itc_from_it (itc, pl->pl_it);
  ITC_IN_KNOWN_MAP (itc, pl->pl_page);
  page_wait_access (itc, pl->pl_page, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
  if (itc->itc_insert_key->key_is_col)
    {
      pl_cpt_col_page (pl, itc, buf, 1);
      return;
    }
  DO_RLOCK (rl, pl)
    {
      if (PL_EXCLUSIVE == PL_TYPE (rl))
	cpt_restore_row (buf, rl->rl_pos, &rd_list);
    }
  END_DO_RLOCK;
  if (!rd_list)
    {
      page_leave_outside_map (buf);
      return;
    }
  ITC_IN_KNOWN_MAP (itc, pl->pl_page);
  itc_delta_this_buffer (itc, buf, 0);
  ITC_LEAVE_MAP_NC (itc);  rds = (row_delta_t **) list_to_array (dk_set_nreverse (rd_list));
  buf_sort ((buffer_desc_t **) rds, BOX_ELEMENTS (rds), (sort_key_func_t) rd_pos_key);
  page_apply (itc, buf, BOX_ELEMENTS (rds), rds, PA_MODIFY);
  rd_list_free (rds);
}


void
cpt_restore_uncommitted (it_cursor_t * itc)
{
  int n_uci = 0;
  itc->itc_ltrx = wi_inst.wi_cpt_lt;
  lt_rb_check (wi_inst.wi_cpt_lt);
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
    {
      if (dbs->dbs_slices)
	continue;
      DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      int inx;
      dk_hash_t * visited = hash_table_allocate (101);
      do {
	for (inx = 0; inx < IT_N_MAPS; inx++)
	  {
	    dk_mutex_t * itm_mtx = &it->it_maps[inx].itm_mtx;
	    mutex_enter (itm_mtx);
	    DO_HT (ptrlong, dp, page_lock_t *, pl, &it->it_maps[inx].itm_locks)
	      {
		if (!gethash ((void*)pl, visited))
		  {
		    sethash ((void*)pl, visited, (void*) 1);
		    mutex_leave (itm_mtx);
		    cpt_pl_restore (pl, itc);
		    cpt_trx_rc_ck ();
		    mutex_enter (itm_mtx);
		  }
	      }
	    END_DO_HT;
	    mutex_leave (itm_mtx);
	  }
      }
      while (!it_all_locks_visited (it, visited));
      hash_table_free (visited);
    }
  END_DO_SET();
    }
  END_DO_SET();
  while (cpt_uci_list)
    {
      uc_insert_t * next = cpt_uci_list->uci_next;
      cpt_reinsert_uci (cpt_uci_list, itc);
      n_uci++;
      cpt_trx_rc_ck ();
      dk_free ((caddr_t) cpt_uci_list, sizeof (uc_insert_t));
      cpt_uci_list = next;
    }
  cpt_col_restore_uncommitted ();
  if (wi_inst.wi_cpt_lt)
    {
      lock_trx_t * lt = wi_inst.wi_cpt_lt;
      /* already inside txn */
      lt_free_rb (lt, 0);
      lt->lt_threads = 1;
      lt->lt_close_ack_threads = 1;
      lt_transact (lt, SQL_COMMIT);
      lt->lt_threads = lt->lt_close_ack_threads = 0;
    }
}


int
cpt_bl_fetch_dir (blob_layout_t * bl, dk_set_t * dir_pages)
{
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  if (!bl->bl_dir_start)
    return BLOB_OK;
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, bl->bl_it);
  bl->bl_page_dir_complete = 0;
  return blob_read_dir (itc, &bl->bl_pages, &bl->bl_page_dir_complete, bl->bl_dir_start, dir_pages);
}


void
cpt_uncommitted_blobs (int clear)
{
  /* when a cpt is done with uncommitted data, the pages of  uncommitted blobs must not appear as taken in the allocation map saved by cpt.  So reset them and then put them back on. */
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
    {
      if (dbs->dbs_slices)
	continue;
      cpt_dbs = dbs;
  if (!clear)
    {
	  DO_HT (ptrlong, dp, void*, ign, dbs->dbs_uc_blob_dps)
	{
	  dbs_cpt_set_allocated (cpt_dbs, dp, 1);
	}
      END_DO_HT;
	  hash_table_free (dbs->dbs_uc_blob_dps);
	  dbs->dbs_uc_blob_dps = NULL;
	  continue;
    }
      dbs->dbs_uc_blob_dps = hash_table_allocate (101);
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (lt->lt_dirty_blobs)
	{
	  DO_HT (void *, k, blob_layout_t *, bl, lt->lt_dirty_blobs)
	    {
	      /* for a blob that is uncommitted, do not record the pages as occupied in the cpt.  But do this only insofar there is a filled page dir.  And do not extend this beyond the first page of the page dir.
	       * So there will be a possible leak of a few pages if roll fwd from the cpt, otherwise no leak. */
		  if (!bl->bl_it || bl->bl_it->it_storage != dbs)
		continue;
	      if (bl->bl_delete_later & BL_DELETE_AT_ROLLBACK)
		{
		  if (bl->bl_pages)
		    {
		      dk_set_t dir_pages = NULL;
		      int inx;
		      if (BLOB_OK != cpt_bl_fetch_dir (bl, &dir_pages))
			{
			  dk_set_free (dir_pages);
			  continue;
			}
		      for (inx= 0; inx < box_length ((caddr_t)bl->bl_pages) / sizeof (dp_addr_t); inx++)
			{
			  if (bl->bl_pages[inx])
			    {
			      {
				dbs_cpt_set_allocated (cpt_dbs, bl->bl_pages[inx], !clear);
				if (clear)
				      sethash (DP_ADDR2VOID (bl->bl_pages[inx]), dbs->dbs_uc_blob_dps, (void*)1);
			      }
			    }
			}
		      DO_SET (ptrlong, dp, &dir_pages)
			{
			  dbs_cpt_set_allocated (cpt_dbs, dp, !clear);
			  if (clear)
				sethash (DP_ADDR2VOID (dp), dbs->dbs_uc_blob_dps, (void*)1);
			}
		      END_DO_SET();
		      dk_set_free (dir_pages);
		    }
		}
	    }
	  END_DO_HT;
	}
    }
  END_DO_SET ();
}
  END_DO_SET();
}



dk_hash_t * cpt_remap_reverse;


void
buf_unremap (buffer_desc_t * buf)
{
  extent_map_t * em = DBS_DP_TO_EM (cpt_dbs, buf->bd_physical_page);
  dp_addr_t phys_dp = buf->bd_physical_page;
  DBG_PT_PRINTF ((" cpt unremapped L=%d P=%d \n", buf->bd_page, buf->bd_physical_page));
  em_free_dp (em, buf->bd_physical_page, EXT_REMAP);
  buf->bd_physical_page = buf->bd_page;
  remhash (DP_ADDR2VOID (buf->bd_page), cpt_dbs->dbs_cpt_remap);
  buf->bd_is_dirty = 1;
  dp_set_backup_flag (cpt_dbs, buf->bd_page, 1);
  if (dbs_is_free_page (cpt_dbs, buf->bd_page))
    {
      log_error ("Suspect to have page unremapped from %d to free page L=%d", phys_dp, buf->bd_page);
    }
}



void
cpt_unremap_ram (int target, int * bufs_done_total)
{
  /* take buffers that already happen to be in memory and unremap them, stop if quota met */
  DO_SET (index_tree_t *, it, &cpt_dbs->dbs_trees)
    {
      int inx;
      for (inx = 0; inx < IT_N_MAPS; inx++)
	{
	  mutex_enter (&it->it_maps[inx].itm_mtx);
	  DO_HT (ptrlong, dp, buffer_desc_t *, buf, &it->it_maps[inx].itm_dp_to_buf)
	    {
	      if (buf->bd_page != buf->bd_physical_page)
		{
		  buf_unremap (buf);
		  *bufs_done_total += 1;
		  if (cpt_dbs->dbs_cpt_remap->ht_count <= target)
		    {
		      mutex_leave (&it->it_maps[inx].itm_mtx);
		      return;
		    }
		}
	    }
	  END_DO_HT;
	  mutex_leave (&it->it_maps[inx].itm_mtx);

	}
    }
  END_DO_SET();
}


void
cpt_em_unremap_read (extent_map_t * em, index_tree_t * it, int * bufs_done, int buf_quota, dk_set_t * bufs_list, int *bufs_done_total)
{
  DO_EXT (ext, em)
    {
      buffer_desc_t ** bufs;
      if (EXT_TYPE (ext) != EXT_REMAP)
	continue;
      bufs = ext_read (it, ext,1, cpt_remap_reverse);
      if (!bufs)
	continue;
      dk_set_push (bufs_list, (void*) bufs);
      *bufs_done += BOX_ELEMENTS (bufs);
      *bufs_done_total += BOX_ELEMENTS (bufs);
      if (*bufs_done > buf_quota)
	goto enough_read;
    }
  END_DO_EXT;
  if (*bufs_done < buf_quota)
    return;
 enough_read: ;
}


void bp_flush_all ();


void
cpt_unremap_bufs (it_cursor_t * itc, dk_set_t * bufs_list)
{
  DO_SET (buffer_desc_t **, bufs, bufs_list)
    {
      int inx;
      DO_BOX (buffer_desc_t *, buf, inx, bufs)
	{
	  itc->itc_tree = buf->bd_tree;
	  ITC_IN_KNOWN_MAP (itc, buf->bd_page);
	  page_wait_access (itc, buf->bd_page, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
	  buf_unremap (buf);
	  buf->bd_registered = NULL;
	  page_leave_outside_map (buf);
	}
      END_DO_BOX;
      dk_free_box ((caddr_t)bufs);
    }
  END_DO_SET();
  bp_flush_all ();
  dk_set_free (*bufs_list);
  *bufs_list = NULL;
  iq_shutdown (IQ_SYNC);
}


void
em_unremap (index_tree_t * it, it_cursor_t * itc, extent_map_t * em, int * bufs_done, int buf_quota, int target, dk_set_t * bufs_list, int *bufs_done_total)
{
  for (;;)
    {
      int l1 = dk_set_length (*bufs_list);
      cpt_em_unremap_read (em, it, bufs_done, buf_quota, bufs_list, bufs_done_total);
      if (l1 == dk_set_length (*bufs_list))
	break;
      if (*bufs_done > buf_quota)
	{
	  cpt_unremap_bufs (itc, bufs_list);
	  *bufs_done = 0;
	}
      else
	break;
      if (cpt_dbs->dbs_cpt_remap->ht_count <= target)
	break;
    }
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
	  if (buf->bd_is_write || buf->bd_readers)
	    GPF_T1 ("buf in cpt tree not supposed to be occupied");
	  buf->bd_tree = NULL;
	  buf->bd_page = 0;
	  buf->bd_is_dirty = 0;
	  buf->bd_storage = NULL;
	}
      clrhash (&cpt_dbs->dbs_cpt_tree->it_maps[inx].itm_dp_to_buf);
      mutex_leave (&cpt_dbs->dbs_cpt_tree->it_maps[inx].itm_mtx);
    }
}




void dbs_cache_check (dbe_storage_t * dbs, int mode);
long cpt_remap_free_logical_pages;
long cpt_reamp_free_physical_pages;
long cpt_reamp_free_pages;

void
cpt_unremap (dbe_storage_t * dbs, it_cursor_t * itc)
{
  int bufs_done = 0, bufs_done_total, buf_quota = main_bufs / 4, target;
  dp_addr_t initial_remaps = 0;
  uint32 start_unremap, end_unremap;
  dk_set_t bufs_list = NULL;
  cpt_remap_reverse = hash_table_allocate (cpt_dbs->dbs_cpt_remap->ht_actual_size);
  cpt_remap_free_logical_pages = cpt_reamp_free_physical_pages = cpt_reamp_free_pages = 0;
  DO_HT (ptrlong, log, ptrlong, phys, dbs->dbs_cpt_remap)
    {
#ifndef NDEBUG
      int pf, lf;
      pf = dbs_is_free_page (dbs, phys);
      lf = dbs_is_free_page (dbs, log);
      if (pf && lf)
	cpt_reamp_free_pages++;
      else if (pf)
	cpt_reamp_free_physical_pages++;
      else if (lf)
	cpt_remap_free_logical_pages++;
#endif
      sethash ((void*)phys, cpt_remap_reverse, (void*)log);
    }
  END_DO_HT;
  initial_remaps = dbs->dbs_cpt_remap->ht_count;
  start_unremap = get_msec_real_time ();
  if (cp_unremap_quota_is_set)
    {
      target = dbs->dbs_cpt_remap->ht_count - cp_unremap_quota;
      if (target < 0)
	target = 0;
      if (target >  dbs->dbs_max_cp_remaps)
	target = dbs->dbs_max_cp_remaps;
    }
  else
    target = MIN (dbs->dbs_max_cp_remaps, (dbs->dbs_cpt_remap->ht_count / 20) * 19);
 again:
  bufs_done_total = 0;
  cpt_unremap_ram (target, &bufs_done_total);
  if (cpt_dbs->dbs_cpt_remap->ht_count > target)
    {
      em_unremap (dbs->dbs_cpt_tree, itc, dbs->dbs_extent_map, &bufs_done, buf_quota, target, &bufs_list, &bufs_done_total);
      cpt_unremap_bufs (itc, &bufs_list);
      bufs_done = 0;
      cpt_place_buffers ();
      DO_SET (index_tree_t *, it, &dbs->dbs_trees)
	{
	  if (it->it_extent_map != dbs->dbs_extent_map && it->it_extent_map)
	    {
	      em_unremap (it, itc, it->it_extent_map, &bufs_done, buf_quota, target, &bufs_list, &bufs_done_total);
	      if (cpt_dbs->dbs_cpt_remap->ht_count <= target)
		break;
	    }
	}
      END_DO_SET();
      cpt_unremap_bufs (itc, &bufs_list);
    }
  bp_flush_all ();
  if (bufs_done_total && cpt_dbs->dbs_cpt_remap->ht_count > target)
    goto again;
  iq_shutdown (IQ_STOP);
  end_unremap = get_msec_real_time ();
  if (end_unremap - start_unremap  > 5000)
    log_info ("Checkpoint removed %d MB of remapped pages, leaving %d MB. Duration %9.4g s.  To save this time, increase MaxCheckpointRemap and/or set Unremap quota to 0 in ini file.", (initial_remaps - dbs->dbs_cpt_remap->ht_count) / PAGES_PER_MB, dbs->dbs_cpt_remap->ht_count / PAGES_PER_MB, (float)(end_unremap - start_unremap) / 1000);
  /* verify all unremaps are written.  shutdown exityy with bufs in iq will lose the pages, very corrupt, often visible as bad parent linkand sometimes as just lost updates.  */
  dbs_cache_check (dbs, IT_CHECK_FAST);
  iq_restart ();
  if (0 == cpt_write_remap (dbs))
    {
      log_error ("Checkpoint remap write failed, %ld remap pages",
		 dbs->dbs_cpt_remap->ht_count);
      target = 0;
      goto again;
    }
  hash_table_free (cpt_remap_reverse);
}


void
cpt_neodisk_page (const void *key, void *value)
{
  dp_addr_t logical = (dp_addr_t) (uptrlong) key;
  dp_addr_t physical = (dp_addr_t) (uptrlong) value;
  buffer_desc_t *after_image;
  if (!physical)
    GPF_T1 ("Zero phys page");
  if (physical == DP_DELETED)
    {
      extent_map_t * em;
      dp_addr_t cp_remap =
	  (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
      if (cp_remap)
	{
	  remhash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
	  em_free_dp (it_from_g->it_extent_map, cp_remap, EXT_REMAP);
	}
      if (it_from_g->it_col_extent_maps)
	em = dbs_dp_to_em  (it_from_g->it_storage, logical);
      else
	em = it_from_g->it_extent_map;
      em_free_dp (em, logical, EMF_INDEX_OR_BLOB);
      dp_set_backup_flag (cpt_dbs, logical, 0);
      DBG_PT_PRINTF (("  cpt clear backup flag L=%d \n", logical));
      return;
    }
  if (!gethash (DP_ADDR2VOID (logical), cpt_dbs->dbs_uc_blob_dps))
    dp_set_backup_flag (cpt_dbs, logical, 1); /* mark page in commit space for backup unless it is an uncommitted blob */
  DBG_PT_PRINTF (("  cpt set backup flag L=%d \n", logical));

  after_image =
    (buffer_desc_t *) gethash (DP_ADDR2VOID (logical), &IT_DP_MAP (it_from_g, logical)->itm_dp_to_buf);
  if (logical == physical)
    {
      dp_addr_t cp_remap =
	  (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
      if (cp_remap)
	{
	  remhash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
	  em_free_dp (it_from_g->it_extent_map, cp_remap, EXT_REMAP);
	}
    }
  else
    {
      dp_addr_t cp_remap =
	  (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (logical), cpt_dbs->dbs_cpt_remap);
      if (cp_remap)
	{
	  GPF_T1 ("A page that has P != L should not additionally have a cpt remap");
	  em_free_dp (it_from_g->it_extent_map, cp_remap, 0);
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
	  em_free_dp (it_from_g->it_extent_map, physical, EXT_REMAP);
	  rdbg_printf (("[C Unremap L %ld R %ld ]", logical, physical));

	  after_image->bd_physical_page = after_image->bd_page;
	  TC (tc_cpt_unremap_dirty);
	}
    }
}


int
cpt_is_page_remapped (dbe_storage_t * dbs, dp_addr_t page)
{
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
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


dk_hash_t *remap;






dk_mutex_t *checkpoint_mtx;




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

extern int dbf_fast_cpt;

void
dbs_backup_check (dbe_storage_t * dbs, int flag)
{
  if (dbf_fast_cpt)
    return;
#if 0
  int n;
  if (flag != CPT_INC_RESET)
    return;
  for (n = 0; n < dbs->dbs_n_pages; n++)
    {
      int fl;
      IN_DBS (dbs);
      fl = dp_backup_flag (dbs, n);
      LEAVE_DBS (dbs);
      if (fl && dbs_is_free_page (dbs, n))
	{
	  log_error (" dp=%d is in backup set and is free\n", n);
	  /*GPF_T1 ("page in backup set and free");*/
	}
    }
#endif
}

void
dbs_cache_check (dbe_storage_t * dbs, int mode)
{
  if (dbf_cpt_rb || dbf_fast_cpt)
    return; /* quick in debug mode */
#ifndef NDEBUG
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      it_cache_check (it, mode);
    }
  END_DO_SET();
#endif
}


void
bp_flush_all ()
{
  int inx;
  DO_BOX (buffer_pool_t *, bp, inx, wi_inst.wi_bps)
    {
      IN_BP (bp);
      mt_write_dirty (bp, 0, 0 /*PHYS_EQ_LOG*/ );
      LEAVE_BP (bp);
    }
  END_DO_BOX;
}


void
dbs_recov_write_page_set (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  while (buf)
    {
      if (buf->bd_next)
	{
	  LONG_SET (buf->bd_buffer + DP_OVERFLOW, buf->bd_next->bd_page);
	}
      else
	LONG_SET (buf->bd_buffer + DP_OVERFLOW, 0);
      print_int (buf->bd_page, dbs->dbs_cpt_recov_ses);
      session_buffered_write_char (DV_STRING, dbs->dbs_cpt_recov_ses);
      print_long (PAGE_SZ, dbs->dbs_cpt_recov_ses);
      session_buffered_write (dbs->dbs_cpt_recov_ses, (caddr_t)buf->bd_buffer, PAGE_SZ);
      buf = buf->bd_next;
    }
}


#define CRH_FREE_SET 0
#define CRH_BACKUP_SET 1
#define CRH_REG_DP 2
#define CRH_REG_ARR 3



#ifdef NOT_CURRENTLY_USED
static void
dbs_cpt_recov_obackup_reset (dbe_storage_t * dbs)
{
  buffer_desc_t * fs = dbs->dbs_free_set;
  buffer_desc_t * is = dbs->dbs_incbackup_set;

  memset (&bp_ctx, 0, sizeof (ol_backup_ctx_t));
  while (fs && is)
    {
      memcpy (is->bd_buffer + DP_DATA, fs->bd_buffer + DP_DATA, PAGE_DATA_SZ);
      page_set_checksum_init (is->bd_buffer + DP_DATA);
      fs = fs->bd_next;
      is = is->bd_next;
    }
  ol_write_registry (dbs, NULL, ol_regist_unmark);
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
#endif


dk_set_t
dbs_cpt_recov_ems (dbe_storage_t * dbs, caddr_t * reg)
{
  dk_set_t all_ems = NULL;
  int inx, n = BOX_ELEMENTS (reg);
  for (inx = 0; inx < n; inx ++)
    {
      caddr_t * ent = (caddr_t*) reg[inx];
      caddr_t name = ent[0];
      if (0 == strncmp (name, "__EM:", 5)
	  || 0 == strcmp (name, "__sys_ext_map"))
	{
	  extent_map_t * em = dbs_read_extent_map (dbs, name, atoi (ent[1]));
	  dk_set_push (&all_ems, (void*)em);
	  if (0 == strcmp (name, "__sys_ext_map"))
	    dbs->dbs_extent_map = em;
	}
    }
  return all_ems;
}


void
dbs_cpt_recov (dbe_storage_t * dbs)
{
  dk_set_t all_ems = NULL;
  int cpt_recov_file_complete = 0;
  extent_map_t * em;
  int cpt_log_fd;
  dk_session_t * ses = dk_session_allocate (SESCLASS_TCPIP);
  long npages = 0, unpages = 0;
  int rc = 0, exit_after_recov = 0;
  char * new_name;
  if (!dbs->dbs_cpt_file_name || dbs->dbs_slices)
    return;
  cpt_log_fd = fd_open (dbs->dbs_cpt_file_name, OPEN_FLAGS_RO);
  if (cpt_log_fd < 0) /* no cpt backup */
    return;
  dbs_cpt_recov_in_progress = 1;
  log_info ("Starting a database that was killed during checkpoint.  Recovering using checkpoint recov file.");
  LSEEK (cpt_log_fd, 0, SEEK_SET);
  tcpses_set_fd (ses->dks_session, cpt_log_fd);
  dbs->dbs_cpt_recov_ses = ses;
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
		  {
		    dp_set_backup_flag (dbs, logical, 0);
		    em = dbs_dp_to_em (dbs, logical);
		    if (em)
		      em_free_dp (em, logical, EMF_ANY);
		    else
		      log_error ("In cpt recov, suspect to have a free that has no em, L=%d ", logical);
		  }
		else
		  {
		    cp_buf->bd_page = logical;
		    dp_set_backup_flag (dbs, logical, 1);
		    if (physical != logical)
		      {
			cp_buf->bd_physical_page = physical;
			cp_buf->bd_storage = dbs;
			buf_disk_read (cp_buf);
			cp_buf->bd_physical_page = logical;
			cp_buf->bd_is_dirty = 1;
			buf_disk_write (cp_buf, logical);
			cp_buf->bd_is_dirty = 0;
			npages ++;
			em = dbs_dp_to_em (dbs, physical);
			if (em)
			  em_free_dp (em, physical, EMF_ANY);
		      }
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
	    case DV_ARRAY_OF_POINTER:
	      /* the recov head block.  Read the sets and extents and the rest here */
	      {
		caddr_t * head = (caddr_t *)obj;
		caddr_t * reg_arr = (caddr_t *)head[CRH_REG_ARR], *reg_arr_2;
		if (!dbs->dbs_registry_hash)
		  {
		    dbs->dbs_registry_hash = id_str_hash_create (101);
		    if (DBS_PRIMARY == dbs->dbs_type)
		      registry = dbs->dbs_registry_hash;
		  }
		dbs->dbs_free_set = dbs_read_page_set (dbs, unbox (head[CRH_FREE_SET]), DPF_FREE_SET);
		dbs->dbs_incbackup_set = dbs_read_page_set (dbs, unbox (head[CRH_BACKUP_SET]), DPF_INCBACKUP_SET);
		dbs->dbs_extent_set = dbs_read_page_set (dbs, dbs->dbs_extent_set->bd_page, DPF_EXTENT_SET);
		dbs->dbs_registry = unbox (head[CRH_REG_DP]);
		reg_arr_2 = (caddr_t*) box_copy_tree ((caddr_t)reg_arr);
		dbs_registry_from_array (dbs, reg_arr);
		head[CRH_REG_ARR] = NULL;
		all_ems = dbs_cpt_recov_ems (dbs, reg_arr_2);
		dk_free_tree ((caddr_t) reg_arr_2);
		break;
	      }
	    default:
	      {
		log_error ("Unknown object in checkpoint recovery file");
		goto err_end;
	      }
	    }
	  dk_free_tree (obj);
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (ses);
  cpt_recov_file_complete = 1;
 err_end:
  dbs->dbs_cpt_recov_ses = NULL;
  fd_close (cpt_log_fd, dbs->dbs_cpt_file_name);
  /* it is read.  Now write the registry and sets and ems */
  if (cpt_recov_file_complete)
    {
      cli_bootstrap_cli ();
      IN_TXN;
      if (LTE_OK != dbs_write_registry (dbs))
	{
	  log_error ("The new registry cannot be written during recov because of no space.  Recovery exits. Make more space available and restart recov");
	  call_exit (-1);
	}
      LEAVE_TXN;
      DO_SET (extent_map_t *, em, &all_ems)
	{
	  dbs_write_page_set (dbs, em->em_buf);
	  em_free_mem (em);
	}
      END_DO_SET ();
      clrhash (dbs->dbs_dp_to_extent_map);
      dk_set_free (all_ems);
      dbs_write_page_set (dbs, dbs->dbs_free_set);
      dbs_write_page_set (dbs, dbs->dbs_incbackup_set);
      dbs_write_page_set (dbs, dbs->dbs_extent_set);
      clrhash (dbs->dbs_cpt_remap);
      if (0 == cpt_write_remap (dbs))
	dbs->dbs_cp_remap_pages = NULL;
      dbs_sync_disks (dbs);
    }
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
  log_info ("%ld pages processed based on checkpoint recov file.", npages);
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
  caddr_t * head, *reg;
  int inx;
  int cpt_log_fd;
  dk_session_t * ses = dk_session_allocate (SESCLASS_TCPIP);
  sch_save_roots (wi_inst.wi_schema);
  registry_update_sequences ();
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
    {
      dk_hash_t * cpt_bkp;
      if (!dbs->dbs_cpt_file_name || dbs->dbs_slices)
	continue;
      cpt_bkp = hash_table_allocate (101);
      cpt_log_fd = fd_open (dbs->dbs_cpt_file_name, OPEN_FLAGS);
      FTRUNCATE (cpt_log_fd, 0);
      LSEEK (cpt_log_fd, 0, SEEK_SET);
      tcpses_set_fd (ses->dks_session, cpt_log_fd);
      dbs->dbs_cpt_recov_ses = ses;
      CATCH_WRITE_FAIL (ses)
	{
	  print_int (0, ses);
	  session_flush_1 (ses);
	  LEAVE_TXN;
	  dbs_recov_write_page_set (dbs, dbs->dbs_extent_set);
	  dbs_cpt_recov_write_extents  (dbs);
	  dbs_recov_write_page_set (dbs, dbs->dbs_free_set);
	  dbs_recov_write_page_set (dbs, dbs->dbs_incbackup_set);
	  IN_TXN;
	  head = (caddr_t *)list (4, box_num (dbs->dbs_free_set->bd_page),
				  box_num (dbs->dbs_incbackup_set->bd_page),
				  box_num (dbs->dbs_registry), dbs_registry_to_array (dbs));
	  print_int (0, ses);
	  print_object (head, ses, NULL, NULL);
	  reg = (caddr_t *) head[CRH_REG_ARR];
	  DO_BOX (caddr_t, elt, inx, reg)
	    {
	      dk_free_box (elt);
	      reg[inx] = NULL;
	    }
	  END_DO_BOX;
	  dk_free_tree (head);
	}
      END_WRITE_FAIL (ses);
      DO_SET (index_tree_t *, it, &dbs->dbs_trees)
	{
	  for (inx = 0; inx < IT_N_MAPS; inx++)
	    {
	      mutex_enter (&it->it_maps[inx].itm_mtx);
	      DO_HT (void *, k, void *, d, &it->it_maps[inx].itm_remap)
		{
		  dp_addr_t logical = (dp_addr_t)(uptrlong) k;
		  dp_addr_t physical = (dp_addr_t)(uptrlong) d;
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
      if (2 == dbs_stop_cp)
	{
	  log_info ("Exiting in mid checkpoint recovery file write");
	  call_exit (-1);
	}
      dbs_sync_disks (dbs);
      LSEEK (cpt_log_fd, 0, SEEK_SET);
      CATCH_WRITE_FAIL (ses)
	{
	  print_int (1, ses);
	  session_flush_1 (ses);
	}
      END_WRITE_FAIL (ses);
      fd_fsync (cpt_log_fd);
      fd_close (cpt_log_fd, dbs->dbs_cpt_file_name);
      hash_table_free (cpt_bkp);
    }
  END_DO_SET();
  PrpcSessionFree (ses);
}

int dbs_stop_cp = 0;

void
dbs_checkpoint (char *log_name, int shutdown)
{
  sys_timer_t _atm;
  char dt_start[DT_LENGTH];
  int mcp_delta_count, inx;
  long start_atomic;
  uint32 start;
  FILE *checkpoint_flag_fd = NULL;
  if (!c_checkpoint_sync)
    dbf_fast_cpt = 1;
  mcp_delta_count = 0;
  LEAVE_TXN;
  if (enable_flush_all)
    {
      int ctr;
      for (ctr = 0; ctr < 2; ctr++)
	{
	  float rate = 0;
	  int n_dirty = dbs_dirty_count (), dirty_after;
	  long n_flush = tc_n_flush;
	  uint32 start = get_msec_real_time ();
	  bp_flush (NULL, 1);
	  start = get_msec_real_time () - start;
	  dirty_after = dbs_dirty_count ();
	  if (0 == ctr)
	    rate = ((tc_n_flush - n_flush) / PAGES_PER_MB) / ((float)start / 1000);
	  if (shutdown)
	    break;
	  if (dirty_after < 10000)
	    break;
	  if (0 == ctr && (float)dirty_after / (n_dirty + 1) > 0.7)
	    {
	      log_info ("Write load very high relative to disk write throughput.  Flushing at %9.2g MB/s while application is making dirty pages at %9.2g MB/s. To checkpoint the database, will now pause the workload with %d MB unflushed.",
			(n_dirty / PAGES_PER_MB) / ((float)start / 1000), (dirty_after / PAGES_PER_MB) / ((float)start / 1000), dirty_after / PAGES_PER_MB);
	      break;
	    }
	  if (0 == ctr && (float)dirty_after / (n_dirty + 1) > 0.2)
	    {
	      log_info ("Write load high relative to disk write throughput.  Flushing at %9.2g MB/s while application is making dirty pages at %9.2g MB/s. Doing a second flushing pass before checkpoint",
			(n_dirty / PAGES_PER_MB) / ((float)start / 1000), (dirty_after / PAGES_PER_MB) / ((float)start / 1000));
	    }
	}
    }
  else
    {
      wi_check_all_compact (0);
      bp_flush_all ();
    }
  if (!shutdown)
    {
  iq_shutdown (IQ_SYNC);
  bp_flush_all ();
  iq_shutdown (IQ_SYNC);
    }

  STI_START;
  IN_TXN;
  cpt_rollback (LT_KILL_FREEZE);
  STI_END (sti_cpt_rollback);
  dt_now ((caddr_t)&dt_start);
  tc_dirty_at_cpt_start += dbs_dirty_count ();
  start_atomic = get_msec_real_time ();
  sti_init (&_atm);
  iq_shutdown (IQ_STOP);
  sti_cum (&sti_cpt_sync, &_atm);
  wi_check_all_compact (0);
  wi_inst.wi_checkpoint_atomic = 1;
  iq_restart ();

  log_info ("Checkpoint started");
  mutex_enter (dbs_autocompact_mtx); /* an autcompact running in the background can confuse the unremap */
  WITHOUT_SIGNALS
  {
    mcp_itc = itc_create (NULL, NULL);
    cpt_uncommitted ();
    cpt_uncommitted_blobs (1);
    checkpoint_flag_fd = fopen(CHECKPOINT_IN_PROGRESS_FILE, "a");
    if (checkpoint_flag_fd != NULL)
      {
	fprintf(checkpoint_flag_fd,
		"If this file exists then a checkpoint started at %d "
		"and has not finished yet",
		get_msec_real_time ());
	fclose(checkpoint_flag_fd);
      }
    bp_flush_all ();
    STI_START;
    iq_shutdown (IQ_STOP);
    STI_END (sti_cpt_sync);
    DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
      {
	if (dbs->dbs_slices)
	  continue;
	STI_START;
	dbs_sync_disks (dbs);
	STI_END (sti_cpt_sync);
      }
    END_DO_SET();
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
    {
      if (dbs->dbs_slices)
	continue;
      dbs_cache_check (dbs, IT_CHECK_ALL);
      dbs_backup_check (dbs, shutdown);
    }
  END_DO_SET();

    dbs_cpt_backup ();
    iq_restart ();
	rdbg_printf (("\nCheckpoint atomic.\n"));
    DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
      {
	if (dbs->dbs_slices)
	  continue;
	cpt_dbs = dbs;
	remap = dbs->dbs_cpt_remap;
	if (1 == dbs_stop_cp)
	  {
	    log_info ("Exiting in mid checkpoint");
	    call_exit (-1);
	  }
	DO_SET (index_tree_t *, it, &dbs->dbs_trees)
	  {
	    mcp_itc->itc_thread = THREAD_CURRENT_THREAD;
	    itc_from_it (mcp_itc, it);
	    it_from_g = it;
	    if (it->it_extent_map && it->it_extent_map->em_remap_on_hold)
	      log_info ("In principle should not have em with remap on hold in cpt. key %s hold %d", it->it_key && it->it_key->key_name ? it->it_key->key_name : "unnamed", it->it_extent_map->em_remap_on_hold);
	    for (inx = 0; inx < IT_N_MAPS; inx++)
	      {
	    rdbg_printf (("%s %ld\n",
		  it->it_key ? it->it_key->key_name : "no key",
			      (long) it->it_maps[inx].itm_remap.ht_count));

		mutex_enter (&it->it_maps[inx].itm_mtx);
		maphash (cpt_neodisk_page, &it->it_maps[inx].itm_remap);
		clrhash (&it->it_maps[inx].itm_remap);
		mutex_leave (&it->it_maps[inx].itm_mtx);
	      }
	  }
	END_DO_SET();
	bp_flush_all ();

	DO_SET (index_tree_t *, del_it, &dbs->dbs_deleted_trees)
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
	END_DO_SET();
	cpt_unremap (dbs, mcp_itc);
	dbs_cpt_extents (dbs, dbs->dbs_deleted_trees);
	dbs_write_registry (dbs);
	dbs_write_page_set (dbs, dbs->dbs_free_set);
	dbs_cpt_write_extents (dbs);
	dk_set_free (dbs->dbs_deleted_trees);
	dbs->dbs_deleted_trees = NULL;
	dbs_write_page_set (dbs, dbs->dbs_incbackup_set);
	dbs_write_page_set (dbs, dbs->dbs_extent_set);
	memcpy(&dbs->dbs_cfg_page_dt, dt_start, DT_LENGTH);
	dbs_write_cfg_page (dbs, 0);
	IN_DBS (dbs);
	LEAVE_DBS (dbs);
      }
    END_DO_SET();
    DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
      {
      if (dbs->dbs_cpt_file_name && !dbs->dbs_slices)
	{
	  STI_START;
	  dbs_sync_disks (dbs);
	  STI_END (sti_cpt_sync);
		unlink (dbs->dbs_cpt_file_name); /* remove cpt backup file */
	}
      }
    END_DO_SET();
    {
      dbe_storage_t * dbs = wi_inst.wi_master;
      cpt_uncommitted_blobs (0);
      cpt_restore_uncommitted (mcp_itc); /* restore uncommitted before log cpt because logcpt may have to rewrite a log of uncommitted if the cpt was between phases of 2pc */
      LEAVE_TXN;
      log_checkpoint (dbs, log_name, shutdown);
      IN_TXN;
      unlink(CHECKPOINT_IN_PROGRESS_FILE);

    }

    mcp_itc->itc_itm1 = NULL;
    itc_free (mcp_itc);
    mcp_itc = NULL;
    uc_printf (("Checkpoint finished. %d delta pages.\n", mcp_delta_count));

    rdbg_printf (("Checkpoint atomic over.\n"));
  }
  RESTORE_SIGNALS;
  mutex_leave (dbs_autocompact_mtx);
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_master_wd->wd_storage)
    {
      if (dbs->dbs_slices)
	continue;
      dbs_cache_check (dbs, IT_CHECK_POST);
      dbs_backup_check (dbs, shutdown);
    }
  END_DO_SET();
  col_dbg_log_new ();
  if (CPT_NORMAL == shutdown)
    cpt_over ();
  auto_cpt_scheduled = 0;
  sti_cum (&sti_cpt_atomic, &_atm);
  atomic_cp_msecs += get_msec_real_time () - start_atomic;

  LEAVE_TXN;
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
      if (cpt_is_page_remapped (dbs, (dp_addr_t) (ptrlong) log))
	ctr++;
    }
  return ctr;
}


void
srv_global_unlock_1 (client_connection_t *cli, lock_trx_t *lt, int was_error)
{
  if (server_lock.sl_owner != THREAD_CURRENT_THREAD)
    GPF_T1 ("not owner of atomic lock");
  server_lock.sl_count--;
  if (0 == server_lock.sl_count)
    {
      IN_TXN;
      if (lt->lt_threads)
	{
	  if (was_error)
	    {
	      lt->lt_is_excl = 0;
	      lt_rollback (lt, TRX_CONT);
	    }
	  else
        lt_commit (lt, TRX_CONT);
	}
      server_lock.sl_owner = NULL;
      server_lock.sl_owner_lt = NULL;
      wi_inst.wi_atomic_ignore_2pc = 0;
      enable_qp = server_lock.sl_qp_save;
      cpt_over ();
      LEAVE_TXN;
      lt->lt_is_excl = 0;
      lt->lt_replicate = (caddr_t*) box_copy_tree ((caddr_t) cli->cli_replicate);
      lt->lt_client->cli_row_autocommit = server_lock.sl_ac_save;
      LEAVE_CPT_1;
    }
}


void
srv_global_unlock (client_connection_t *cli, lock_trx_t *lt)
{
  srv_global_unlock_1 (cli, lt, 0);
}


int32 cl_retry_seed;

void
srv_global_lock (query_instance_t * qi, int flag)
{
  int retries = 0;
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
    again:
      {
	int rc;
	caddr_t err = NULL;
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
      wi_inst.wi_atomic_ignore_2pc = 0 != (flag & SRVL_CL_CONFIG);
      server_lock.sl_count = 1;
      server_lock.sl_owner_lt = lt;
      lt->lt_is_excl = 1;
      lt->lt_replicate = REPL_NO_LOG;
      IN_TXN;
      server_lock.sl_owner = THREAD_CURRENT_THREAD;
      cpt_rollback (LT_KILL_ROLLBACK);
      lt_threads_set_inner (lt, 1);
      LEAVE_TXN;
      server_lock.sl_ac_save = lt->lt_client->cli_row_autocommit;
      lt->lt_client->cli_row_autocommit = 1;
      server_lock.sl_qp_save = enable_qp;
      enable_qp = 1;
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
cpt_is_global_lock (lock_trx_t * lt)
{
  lock_trx_t * owner_lt;
  if (!server_lock.sl_owner)
    return 0;
  owner_lt = server_lock.sl_owner_lt;
  if (owner_lt && lt
      && (lt == owner_lt || lt->lt_rc_w_id == owner_lt->lt_w_id || lt->lt_main_trx_no == owner_lt->lt_trx_no))
    return 0;
  if (server_lock.sl_owner != THREAD_CURRENT_THREAD)
    return 1;

  return 0;
}


int
srv_have_global_lock (du_thread_t *thr)
{
  return (server_lock.sl_owner && server_lock.sl_owner == thr);
}
