/*
 *  rltrx.c
 *
 *  $Id$
 *
 *  Locking concurrency control
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
#include "statuslog.h"
#include "wifn.h"

#ifdef VIRTTP
#include "2pc.h"
#endif
int dive_cache_threshold = 20;	/* % consecutive for dive cache to be active */

#ifdef PAGE_TRACE
int lock_escalation_pct = 111;
#else
int lock_escalation_pct = 50;
#endif

#define ASSERT_LOCK_READ(itc, buf) \
  if (!buf->bd_is_write || itc->itc_page != buf->bd_page) \
    GPF_T1("no excl. page access")





void
itc_escalate_lock (it_cursor_t * itc, int ltype)
{
  int inx;
  page_lock_t *pl = itc->itc_pl;
#if 0
  DO_SET (lock_trx_t *, any_lt, &all_trxs)
    {
      if (any_lt != itc->itc_ltrx)
	if (dk_set_member (any_lt->lt_locks, (void*)pl))
	  GPF_T1 ("escalating a lock with multiple references");
    }
  END_DO_SET();
#endif
  if (pl->pl_page != itc->itc_page)
    GPF_T1 ("inconsistent pages in lock esc");
  rdbg_printf (("Escalate T=%ld L=%d PL=%x \n", TRX_NO (itc->itc_ltrx), itc->itc_page, pl));

  PL_SET_FLAG (pl, PL_PAGE_LOCK);
  DO_RLOCK (rl, pl)
  {
    if (rl->pl_waiting
	|| rl->pl_owner != itc->itc_ltrx)
      GPF_T1 ("can't escalate when more than one lock owner");
    if (PL_EXCLUSIVE == PL_TYPE (rl))
      ltype = PL_EXCLUSIVE;
    rl_free (rl);
  }
  END_DO_RLOCK;

  PL_SET_TYPE (pl, ltype);
  PL_SET_FLAG (pl, PL_PAGE_LOCK);
  pl->pl_n_row_locks = 0;
  for (inx = 0; inx < N_RLOCK_SETS; inx++)
    pl->pl_rows[inx] = NULL;
  itc->itc_n_lock_escalations++;
  if (itc->itc_insert_key)
    itc->itc_insert_key->key_lock_escalations++;
}



void
pl_rlock_table (page_lock_t * pl, row_lock_t ** locks, int *fill_ret)
{
  int inx;
  int fill = 0;
  if (!pl)
    {
      *fill_ret = 0;
      return;
    }
  DO_RLOCK (rl, pl)
  {
    locks[fill++] = rl;
  }
  END_DO_RLOCK;
  *fill_ret = fill;
  for (inx = 0; inx < N_RLOCK_SETS; inx++)
    pl->pl_rows[inx] = NULL;
  pl->pl_n_row_locks = 0;
}


void
rl_add_pl_to_owners (it_cursor_t * itc, row_lock_t * rl, page_lock_t * pl)
{
  it_cursor_t *waiting;
  if (rl->pl_is_owner_list)
    {
      dk_set_t rl_owner = (dk_set_t) rl->pl_owner;
      DO_SET (lock_trx_t *, owner, &rl_owner)
      {
	lt_add_pl (owner, pl, 0);
      }
      END_DO_SET ();
    }
  else
    lt_add_pl (rl->pl_owner, pl, 0);
  waiting = rl->pl_waiting;
  while (waiting)
    {
      lt_add_pl (waiting->itc_ltrx, pl, 0);
      rdbg_printf (("   rl %p moved, waiting lt %p added to pl %p\n", rl, waiting->itc_ltrx, pl));
      waiting = waiting->itc_next_on_lock;
    }
}


void
pg_move_lock (it_cursor_t * itc, row_lock_t ** locks, int n_locks, int from, int to,
	      page_lock_t * pl_to, int is_to_extend)
{
  int inx;
  for (inx = 0; inx < n_locks; inx++)
    {
      row_lock_t *rl = locks[inx];
      if (rl && rl->rl_pos == from)
	{
	  locks[inx] = NULL;
	  /* rdbg_printf (("	rl %d to %d %s\n", rl->rl_pos, to, is_to_extend ? "ext" : "")); */
	  rl->rl_pos = to;
	  rl->rl_next = PL_RLS (pl_to, to);
	  PL_RLS (pl_to, to) = rl;
	  pl_to->pl_n_row_locks++;
	  if (is_to_extend)
	    rl_add_pl_to_owners (itc, rl, pl_to);
	  return;
	}
    }
}


void
itc_split_lock (it_cursor_t * itc, buffer_desc_t * left, buffer_desc_t * extend)
{
  page_lock_t *left_pl = itc->itc_pl;
  page_lock_t *extend_pl;
  if (!left_pl)
    return;
  extend_pl = pl_allocate ();
  extend_pl->pl_page = extend->bd_page;
  PL_SET_TYPE (extend_pl, PL_EXCLUSIVE);
  extend_pl->pl_it = itc->itc_tree;

  ITC_IN_TRANSIT (itc, left->bd_page, extend->bd_page);
  sethash (DP_ADDR2VOID (extend->bd_page), &IT_DP_MAP (itc->itc_tree, extend->bd_page)->itm_locks, (void *) extend_pl);
  extend->bd_pl = extend_pl;
  mtx_assert (itc->itc_pl == IT_DP_PL (itc->itc_tree, left->bd_page));
  if (PL_IS_FINALIZE (left_pl))
    PL_SET_FLAG (extend_pl, PL_FINALIZE);
#if 1
  if (PL_IS_PAGE (left_pl))
    {
      extend_pl->pl_type = left_pl->pl_type;

      if (left_pl->pl_is_owner_list)
	{
	  TC (tc_pl_split_multi_owner_page);
	  extend_pl->pl_is_owner_list = 1;
	  DO_SET (lock_trx_t *, owner, (dk_set_t *) &left_pl->pl_owner)
	    {
	      dk_set_push ((dk_set_t *) &extend_pl->pl_owner, (void *) owner);
	      lt_add_pl (owner, extend_pl, 0);
	    }
	  END_DO_SET();
	}
      else
	{
	  extend_pl->pl_owner = left_pl->pl_owner;
	  lt_add_pl (left_pl->pl_owner, extend_pl, 1);
	}

      TC (tc_pl_split);
    }
  else
    lt_add_pl (itc->itc_ltrx, extend_pl, 1);
#else
  if (PL_IS_PAGE (left_pl))
    {
      if (PL_TYPE (left_pl) != PL_EXCLUSIVE)
	GPF_T1 ("non-exclusive page lock on split");
      extend_pl->pl_owner = left_pl->pl_owner;
      PL_SET_FLAG (extend_pl, PL_PAGE_LOCK);
      TC (tc_pl_split);
    }
  lt_add_pl (itc->itc_ltrx, extend_pl, 1);
#endif

  /* must add after PL_IS_PAGE is set. If row level, extend_pl
   * may end up empty but that's OK. The last referencing txn will free it */
}


void
itc_split_lock_waits (it_cursor_t * itc, buffer_desc_t * left, buffer_desc_t * extend)
{
  page_lock_t *extend_pl;
  page_lock_t *left_pl;
  ITC_IN_TRANSIT  (itc, left->bd_page, extend->bd_page);
  left_pl = IT_DP_PL (itc->itc_tree, left->bd_page);
  if (!left_pl)
    return;
  extend_pl = IT_DP_PL (itc->itc_tree, extend->bd_page);
  {
    it_cursor_t **last = &extend_pl->pl_waiting;
    it_cursor_t *waiting = left_pl->pl_waiting;
    it_cursor_t **prev = &left_pl->pl_waiting;
    while (waiting)
      {
	it_cursor_t *next = waiting->itc_next_on_lock;
	if (waiting->itc_page == extend->bd_page)
	  {
	    TC (tc_pl_split_while_wait);
	    *last = waiting;
	    waiting->itc_next_on_lock = NULL;
	    last = &waiting->itc_next_on_lock;
	    *prev = next;
	    rdbg_printf (("LW PL move from PL %x to PL=%x waiting T=%d \n", left_pl, extend_pl, waiting->itc_ltrx->lt_trx_no));
	    lt_add_pl (waiting->itc_ltrx, extend_pl, 0);
	    lt_clear_pl_wait_ref (waiting->itc_ltrx, (gen_lock_t *) left_pl);
	    /* if had a wait ref to the left side of split and now to the right side, drop the wait ref. Add the new wait ref.
	    * assumed that only one cr per txn on the lock but always so since single running thread per txn. */
	  }
	else
	  prev = &waiting->itc_next_on_lock;
	waiting = next;
      }
  }
}


row_lock_t *
pl_row_lock_at (page_lock_t * pl, int pos)
{
  row_lock_t *rl = PL_RLS (pl, pos);
  while (rl)
    {
      if (rl->rl_pos == pos)
	return rl;
      rl = rl->rl_next;
    }
  return NULL;
}


row_lock_t *
upd_refit_rlock (it_cursor_t * itc, int pos)
{
  page_lock_t *pl = itc->itc_pl;
  row_lock_t **prev;
  row_lock_t *rl;
  if (itc->itc_ltrx->lt_is_excl)
    return NULL;
  prev = &PL_RLS (pl, pos);
  rl = *prev;

  while (rl)
    {
      if (rl->rl_pos == pos)
	{
	  *prev = rl->rl_next;
	  pl->pl_n_row_locks--;
	  /* rdbg_printf (("	refit rl at %d on %ld\n", rl->rl_pos, pl->pl_page)); */
	  return rl;
	}
      prev = &rl->rl_next;
      rl = rl->rl_next;
    }
  return NULL;
}


int
itc_check_ins_deleted (it_cursor_t * itc, buffer_desc_t * buf, db_buf_t dv)
{
  db_buf_t page = buf->bd_buffer;
  int pos = itc->itc_position;
  long l;
  l = row_length (page + pos, itc->itc_insert_key);
  if (IE_ISSET (page + pos, IEF_DELETE))
    {
      itc->itc_row_key = sch_id_to_key (wi_inst.wi_schema, itc->itc_row_key_id);
      if (!itc->itc_pl)
	{
	  log_error ("insert on a deleted row not of this transaction.  Can be the deleted flag is left on from before, from a finished transaction or cpt kill recovery");
	  itc_set_lock_on_row (itc, &buf);
	}
      upd_refit_row (itc, &buf, dv);
      return 1;
    }
  return 0;
}


void
itc_make_pl (it_cursor_t * itc, buffer_desc_t * buf)
{
  dp_addr_t dp = itc->itc_page;
  page_lock_t *pl = pl_allocate ();
  pl->pl_it = itc->itc_tree;
  ITC_IN_KNOWN_MAP (itc, itc->itc_page);
  sethash (DP_ADDR2VOID (dp), &IT_DP_MAP (itc->itc_tree, itc->itc_page)->itm_locks, (void *) pl);
  if (buf)
    buf->bd_pl = pl;
  pl->pl_page = dp;
  pl->pl_type = itc->itc_lock_mode;
  ITC_LEAVE_MAP_NC (itc);
  itc->itc_pl = pl;
  lt_add_pl (itc->itc_ltrx, pl, 1);
}


void
itc_insert_rl (it_cursor_t * itc, buffer_desc_t * buf, int pos, row_lock_t * rl, int no_escalation)
{
  it_cursor_t * waiting;
  int not_own = 0;
  int new_pl = 0;
  page_lock_t *pl = itc->itc_pl;
  if (itc->itc_ltrx->lt_is_excl
      || INS_DOUBLE_LP == rl)
    return;
  if (!pl)
    {
#ifdef MTX_DEBUG
      if (buf && buf->bd_writer != THREAD_CURRENT_THREAD)
	GPF_T1 ("Thread not writer of buffer in insert row lock");
#endif
      itc_make_pl (itc, buf);
      pl = itc->itc_pl;
      new_pl = 1;
    }
  if (pl && pl->pl_page != itc->itc_page)
    GPF_T1 ("inconsistent itc_pl for insert rlock");

  if (PL_IS_PAGE (pl))
    {
      if (pl->pl_owner != itc->itc_ltrx)
	GPF_T1 ("not owner in insert page lock");
      return;
    }
  ITC_MARK_LOCK_SET (itc);
  if (INS_NEW_RL == rl)
    {
      if (!no_escalation && buf && PL_CAN_ESCALATE (itc, pl, buf))
	{
	  itc_escalate_lock (itc, PL_EXCLUSIVE);
	  return;
	}
      rl = rl_allocate ();
    }
  rl->rl_next = PL_RLS (pl, pos);
  PL_RLS (pl, pos) = rl;
  /* if icts wait for the rl of a row that has grown and made a split, make sure the waiting lyt's get to be owners of the lock also if the itc ended up on the extend side of the split */
  waiting = rl->pl_waiting;
  while (waiting)
    {
      lt_add_pl (waiting->itc_ltrx, itc->itc_pl, 0);
      waiting = waiting->itc_next_on_lock;
    }
  if (itc->itc_ltrx->lt_status != LT_PENDING)
    rdbg_printf (("*** making posthumous ins lock T=%ld L=%d \n", TRX_NO (itc->itc_ltrx), itc->itc_page));

  pl->pl_n_row_locks++;
  /* rdbg_printf (("       rl insert at %d on %ld\n", pos, pl->pl_page)); */
  rl->pl_type = PL_EXCLUSIVE;
  rl->pl_owner = itc->itc_ltrx;
  rl->rl_pos = pos;
  if (!new_pl
      || (not_own = !pl_lt_is_owner (pl, itc->itc_ltrx)))
    {
      if (not_own)
	rdbg_printf (("would be miss insert pl T=%ld L=%d \n", TRX_NO (itc->itc_ltrx), itc->itc_page));
      lt_add_pl (itc->itc_ltrx, pl, 0);
    }
}


int
itc_insert_lock (it_cursor_t * itc, buffer_desc_t * buf, int *res_ret)
{
  int res = *res_ret;
  page_lock_t *pl = itc->itc_pl;
  if (!pl)
    return NO_WAIT;
  if (PL_IS_PAGE (pl))
    {
      return (lock_enter ((gen_lock_t *) pl, itc, buf));
    }
  if (DVC_LESS == res)
    {
      row_lock_t *rl = pl_row_lock_at (itc->itc_pl, itc->itc_position);
      if (!rl)
	return NO_WAIT;
      if (RL_IS_FOLLOW (rl) && rl->pl_owner != itc->itc_ltrx)
	{
	  TC (tc_insert_follow_wait);
	  lock_wait ((gen_lock_t *) rl, itc, buf, ITC_NO_LOCK);
	  return WAIT_OVER;
	}
      return NO_WAIT;
    }
  if (DVC_MATCH == res)
    {
      row_lock_t *rl = pl_row_lock_at (pl, itc->itc_position);
      if (rl)
	if (!lock_add_owner ((gen_lock_t *) rl, itc, 0))
	  {
	    lock_wait ((gen_lock_t *) rl, itc, buf, ITC_NO_LOCK);
	    return WAIT_OVER;
	  }
      return NO_WAIT;
    }
  return NO_WAIT;
}


int
lock_is_acquirable (gen_lock_t * pl, it_cursor_t * itc)
{
  /* for a repeatable read cursor check that it can get this lock
   * if it decides to as long as itc does not leave the page before calling itc_set_lock_on_row. */
  if (pl->pl_owner == itc->itc_ltrx)
    return 1;
  if (PL_TYPE (pl) == PL_EXCLUSIVE)
    return 0;
  if (PL_SHARED == PL_TYPE (pl))
    {
      if (pl->pl_is_owner_list
	  && dk_set_member ((dk_set_t) pl->pl_owner, (void*) itc->itc_ltrx))
	return 1;
      if (PL_SHARED == itc->itc_lock_mode
	  && !pl->pl_waiting)
	return 1;
    }
  else
    GPF_T1 ("lock not shared nor exclusive");
  return 0;
}



int
itc_landed_lock_check (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  page_lock_t *pl = itc->itc_pl;
  if (itc->itc_isolation == ISO_UNCOMMITTED)
    return NO_WAIT;
  if (!ITC_IS_LTRX (itc))
    GPF_T1 ("non-trx cursor shall not check locks");

  if (ISO_SERIALIZABLE == itc->itc_isolation)
    {
      if (leaf_pointer ((*buf_ret)->bd_buffer, itc->itc_position))
	return NO_WAIT;  /* only a leaf can be locked */
      /* the point of setting the itc_is_on_row flag is to acquire the lock in case of wait.  A RR cursor will not acquire the lock before it has checked all the row criteria but a serializable will */
      itc->itc_is_on_row = 1;
      return (itc_set_lock_on_row (itc, buf_ret));
    }
  if (!pl)
    return NO_WAIT;
  if (PL_IS_PAGE (pl))
    {
      if (!lock_is_acquirable ((gen_lock_t *) pl, itc))
	{
	  lock_wait ((gen_lock_t *) pl, itc, *buf_ret, ITC_NO_LOCK);
	  *buf_ret = page_reenter_excl (itc);
	  return WAIT_OVER;
	}
      if (pl->pl_owner == itc->itc_ltrx && PL_TYPE (pl) == itc->itc_lock_mode)
	itc->itc_owns_page = itc->itc_page;
      return NO_WAIT;
    }
  else
    {
      row_lock_t *rl = pl_row_lock_at (pl, itc->itc_position);
      if (!rl)
	return NO_WAIT;
      if (!lock_is_acquirable ((gen_lock_t *) rl, itc))
	{
	  /*int is_cus = 0, cus_pos1;*/
	  lock_wait ((gen_lock_t *) rl, itc, *buf_ret, ITC_NO_LOCK);
	  *buf_ret = page_reenter_excl (itc);
	  return WAIT_OVER;
	}
    }
  return NO_WAIT;
}

#ifdef PAGE_TRACE
#define LT_CHECK_NEW_PL(lt, pl) \
  if (dk_set_member (lt->lt_locks, (void*) pl)) GPF_T1 ("duplicate pl in lt")
#else
#define LT_CHECK_NEW_PL(lt, pl)
#endif


int
pl_lt_is_owner (page_lock_t * pl, lock_trx_t * lt)
{
  /* is the lt already an owner of the pl? */
  if (pl->pl_owner == lt)
    return 1;
  if (pl->pl_is_owner_list
      && dk_set_member ((dk_set_t) pl->pl_owner, (void*) lt))
    return 1;
  return 0;
}


void
lt_add_pl (lock_trx_t * lt, page_lock_t * pl, int is_new_pl)
{
  if (PL_IS_PAGE (pl))
    {
      if (is_new_pl)
	{
	  IN_LT_LOCKS (lt);
	  LT_CHECK_NEW_PL (lt, pl);
	  sethash ((void*)pl, &lt->lt_lock, (void*)1);
	  LEAVE_LT_LOCKS (lt);
	}
      else
	{
	  IN_LT_LOCKS (lt);
	  sethash ((void*)pl, &lt->lt_lock, (void*)1);
	  LEAVE_LT_LOCKS (lt);
	}
    }
  else
    {
      /* for a row level pl, the pl_owners is the union of lt's
       * which reference this pl wither because of rl ownership or past / present wait at rl */
      if (pl->pl_is_owner_list)
	{
	  if (dk_set_member ((dk_set_t) pl->pl_owner, (void *) lt))
	    return;
	  dk_set_push ((dk_set_t *) & pl->pl_owner, (void *) lt);
	  IN_LT_LOCKS  (lt);
	  sethash ((void*)pl, &lt->lt_lock, (void*)1);
	  LEAVE_LT_LOCKS (lt);
	}
      else if (lt == pl->pl_owner)
	return;
      else if (pl->pl_owner == NULL)
	{
	  pl->pl_owner = lt;
	  IN_LT_LOCKS (lt);
	  LT_CHECK_NEW_PL (lt, pl);
	  sethash ((void*)pl, &lt->lt_lock, (void*)1);
	  LEAVE_LT_LOCKS (lt);
	}
      else
	{
	  lock_trx_t *prev = pl->pl_owner;
	  pl->pl_is_owner_list = 1;
	  pl->pl_owner = NULL;
	  dk_set_push ((dk_set_t *) & pl->pl_owner, (void *) prev);
	  dk_set_push ((dk_set_t *) & pl->pl_owner, (void *) lt);
	  IN_LT_LOCKS (lt);
	  LT_CHECK_NEW_PL (lt, pl);
	  sethash ((void*)pl, &lt->lt_lock, (void*)1);
	  LEAVE_LT_LOCKS (lt);
	}
    }
}


void
itc_make_rl (it_cursor_t * itc)
{
#ifdef DEBUG
  client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
#endif
  page_lock_t *pl = itc->itc_pl;
  row_lock_t *rl = rl_allocate ();
#if 0 /* Disabled according to Orri's instruction 2007-JUL-19 */ 
#ifdef DEBUG
  if (cli && cli->cli_autocommit && itc->itc_ltrx == cli->cli_trx)
    GPF_T1 ("row lock on the cli_trx");
#endif
#endif
  if (pl->pl_page != itc->itc_page)
    GPF_T1 ("itc has itc_pl of a different page");

  if (itc->itc_ltrx->lt_status != LT_PENDING)
    rdbg_printf (("*** making posthumous lock T=%ld L=%d \n", TRX_NO (itc->itc_ltrx), itc->itc_page));
  assert (itc->itc_position);
  rl->rl_pos = itc->itc_position;
  rl->rl_next = PL_RLS (pl, itc->itc_position);
  PL_RLS (pl, itc->itc_position) = rl;
  pl->pl_n_row_locks++;
  /* rdbg_printf (("	rl set at %d on %ld %d total\n", rl->rl_pos, pl->pl_page, pl->pl_n_row_locks)); */
  rl->pl_type = itc->itc_lock_mode;
  if (itc->itc_isolation == ISO_SERIALIZABLE
      && itc->itc_search_mode != SM_INSERT)
    PL_SET_FLAG (rl, RL_FOLLOW);
  rl->pl_owner = itc->itc_ltrx;
  ITC_MARK_LOCK_SET (itc);
}


int
itc_set_lock_on_row (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  row_lock_t *rl;
  int rc;
  page_lock_t *pl = itc->itc_pl;
#ifdef MTX_DEBUG
  if ((*buf_ret)->bd_writer != THREAD_CURRENT_THREAD)
    GPF_T1 ("the thread setting a lock is not the writer of the buffer");
#endif
  if (!(*buf_ret)->bd_is_write)
    GPF_T1 ("itc_set_lock_on_row needs excl. page access");
  if (!ITC_IS_LTRX (itc)
      || (itc->itc_lock_mode == PL_SHARED && itc->itc_isolation < ISO_REPEATABLE))
    return NO_WAIT;
  if (!SHORT_REF ((*buf_ret)->bd_buffer + itc->itc_position + IE_KEY_ID))
    {
      return NO_WAIT;
      /*GPF_T1 ("cannot set lock on leaf ptr");*/
    }
  if (pl)
    {
      if (pl->pl_page != itc->itc_page)
	GPF_T1 ("pl and itc on different pages");
      if (PL_IS_PAGE (pl))
	{
	  rc = lock_enter ((gen_lock_t *) itc->itc_pl, itc, *buf_ret);
	  if (NO_WAIT == rc)
	    return rc;
	  *buf_ret = page_reenter_excl (itc);
	  return rc;
	}
      rl = pl_row_lock_at (pl, itc->itc_position);
      if (rl)
	{
	  rc = lock_enter ((gen_lock_t *) rl, itc, *buf_ret);
	  if (NO_WAIT == rc)
	    {
	      if (itc->itc_isolation == ISO_SERIALIZABLE
	      && itc->itc_search_mode != SM_INSERT)
	    PL_SET_FLAG (rl, RL_FOLLOW);
	    return rc;
	    }
	  *buf_ret = page_reenter_excl (itc);
	  return rc;
	}
      else
	{
	  ITC_MARK_LOCK_SET (itc);
	  if (PL_CAN_ESCALATE (itc, pl, (*buf_ret)))
	    {
	      itc_escalate_lock (itc, itc->itc_lock_mode);
	      itc->itc_owns_page = itc->itc_page;
	      return NO_WAIT;
	    }
	  itc_make_rl (itc);
	  lt_add_pl (itc->itc_ltrx, pl, 0);
	  return NO_WAIT;
	}
    }
  else
    {
#if defined (MTX_DEBUG) || defined (PAGE_TRACE)
      ITC_IN_OWN_MAP (itc);
      if (IT_DP_PL (itc->itc_tree, itc->itc_page))
	GPF_T1 ("itc_pl null when there is a pl");
      ITC_LEAVE_MAP_NC (itc);
#endif
      itc_make_pl (itc, *buf_ret);
      if (ITC_PREFER_PAGE_LOCK (itc))
	{
	  PL_SET_FLAG (itc->itc_pl, PL_PAGE_LOCK);
	  itc->itc_owns_page = itc->itc_page;
	  ITC_MARK_LOCK_SET (itc);
	  if (itc->itc_insert_key)
	    itc->itc_insert_key->key_lock_escalations++;
	}
      else
	{
	  itc_make_rl (itc);
	}
      return NO_WAIT;
    }
}


long tc_serializable_land_reset;

int
itc_serializable_land (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  if (NO_WAIT == itc_set_lock_on_row (itc, buf_ret))
    {
      if (itc->itc_desc_order)
	{
	  /* for desc serializable, must lock the row above the range.  So the reset test for getting the first lock is not here but later */
	  itc->itc_desc_serial_landed = 1;
    return NO_WAIT;
	}
      return NO_WAIT;
    }
  TC (tc_serializable_land_reset);
  ITC_IN_KNOWN_MAP (itc, (*buf_ret)->bd_page);
  rdbg_printf (("  serializable landing reset T=%d L=%d pos=%d \n", TRX_NO (itc->itc_ltrx), itc->itc_page, itc->itc_position));
  page_leave_inner (*buf_ret);
  ITC_LEAVE_MAP_NC (itc);
  *buf_ret = itc_reset (itc);
  return WAIT_OVER;
}


int
itc_read_committed_check (it_cursor_t * itc, int pos, buffer_desc_t * buf)
{
  rb_entry_t *rbe;
  db_buf_t page;
  page_lock_t * pl = buf->bd_pl;
  gen_lock_t * gl;
  if (PL_IS_PAGE (pl))
    gl = (gen_lock_t *) pl;
  else 
    {
      gl = (gen_lock_t *) pl_row_lock_at (pl, pos);
      if (!gl)
	return DVC_MATCH;
    }

  if (PL_EXCLUSIVE != PL_TYPE (gl))
    return DVC_MATCH;
  /* the lock concerns this row, either ecl row lock hwre or excl page lock on page */
  page = buf->bd_buffer;
  if (itc->itc_ltrx == gl->pl_owner)
    return (IE_ISSET (page + pos, IEF_DELETE)) ? DVC_LESS : DVC_MATCH;
  /* this is somebody else's lock.  Get the rb record. 
   * Note that if the owner is committing at this time, this cr may have seen a after image  row before but here it will see a pre image . 
   * To prevent this, use repeatable.  Read committed only means that no uncommitted states are shown, not that you do not get half transactions.  
   * If showing half transactions in read committtedf is good enough for Oracle it is good enough for us. */
  
  rbe = lt_rb_entry (gl->pl_owner, page + pos, NULL, NULL, 1);
  if (!rbe)
    return DVC_MATCH; /* row not modified, just locked */
  if (RB_INSERT == rbe->rbe_op)
    return DVC_LESS; /* uncommitted insert */
  itc->itc_row_data = rbe->rbe_string + rbe->rbe_row + IE_FIRST_KEY; 
  /* rbe and related will stay allocated as long as the page is taken.  Will only disappear after the owner has finalized this page. */
  return DVC_MATCH;
}


void
itc_lock_failure (it_cursor_t * itc, char * msg)
{
  rdbg_printf (("*** No lock itc %p L=%ld pos=%d K=%s ISO=%d LM=%d %s\n",
	  itc, (unsigned long) itc->itc_page, itc->itc_position, itc->itc_insert_key ? itc->itc_insert_key->key_name : "no key",
	  (int) itc->itc_isolation, (int) itc->itc_lock_mode, msg));

#if 0
#ifndef NDEBUG
  GPF_T1 ("itc_assert_locksseems inconsistent");
#endif
#endif
}


int
lock_is_owner (gen_lock_t * pl, lock_trx_t * lt, it_cursor_t * itc)
{
  int mode = itc->itc_lock_mode;
  if (!pl)
    {
      itc_lock_failure (itc, "There is supposed to be a lock");
      return 0;
    }
  if (lt == pl->pl_owner)
    return 1;
  if (mode == PL_EXCLUSIVE && PL_TYPE (pl) != PL_EXCLUSIVE)
    {
      itc_lock_failure (itc, "lock is supposed to be exclusive");
      return 0;
    }
  if (pl->pl_is_owner_list)
    if (dk_set_member ((dk_set_t) pl->pl_owner, (void*) lt))
      return 1;
  return 0;
}


void
itc_assert_lock_1 (it_cursor_t * itc)
{
  if (!ITC_IS_LTRX (itc))
    return;
  ITC_IN_OWN_MAP (itc);
  if (itc->itc_pl != IT_DP_PL (itc->itc_tree, itc->itc_page))
    {
      ITC_LEAVE_MAPS (itc);
      itc_lock_failure (itc, "mismatched itc and itc_pl");
      return;
    }
  ITC_LEAVE_MAPS (itc);
  if (itc->itc_isolation < ISO_REPEATABLE
      || !itc->itc_is_on_row)
    return;
  if (!itc->itc_pl)
    {
      itc_lock_failure (itc, "itc is supposed to have a pl");
      return;
    }
  if (PL_IS_PAGE (itc->itc_pl))
    {
      if (!lock_is_owner ((gen_lock_t *) itc->itc_pl, itc->itc_ltrx, itc))
	{
	  itc_lock_failure (itc, "itc does not own page lock");
	  return;
	}
    }
  else
    {
      row_lock_t * rl = pl_row_lock_at (itc->itc_pl, itc->itc_position);
      if (!lock_is_owner ((gen_lock_t *) rl, itc->itc_ltrx, itc))
	{
	  itc_lock_failure (itc, "itc is supposed to have row lock");
	  return;
	}
    }
}


void
itc_assert_lock (it_cursor_t * itc)
{
#if 0
  return;
#else
  itc_assert_lock_1 (itc);
#endif
}

void
itc_leave_page_locks (it_cursor_t * itc)
{
  /* if page all locked, escalate, if nothing locked, free the pl */
}


void
pl_set_finalize (page_lock_t * pl, buffer_desc_t * buf)
{
  if (!pl)
    GPF_T1("pl should not be null in pl_set_finalize");
  PL_SET_FLAG (pl, PL_FINALIZE);
}


#define PAGE_NOT_CHANGED 0
#define PAGE_UPDATED 1
#define PAGE_DELETED 2
#define LEAF_CHG_MASK 4
/* LEAF_CHG_MASK is on in the rc if the first row was deleted.  Thhis means that the leaf ptr should begin with the key of the first row. 
 * This is nice to have in order to avoid inserts to non leaf and in order not to miss follow locks on previous pages.  The point is that the seek must land beside the next smaller and if leaf ptrs are out of whack this is not always so */

int
itc_finalize_row (it_cursor_t * itc, buffer_desc_t ** buf_ret, int pos)
{
  buffer_desc_t *buf = *buf_ret;
  buffer_desc_t *buf_from = buf;
  db_buf_t page = buf->bd_buffer;
  long l;
  if (0 == pos)
    {
      TC (tc_deld_row_rl_rb);
      return PAGE_NOT_CHANGED;
    }
  itc->itc_position = pos;

  if (IE_ISSET (page + pos, IEF_DELETE))
    {
      int is_first = itc->itc_position == SHORT_REF (page + DP_FIRST);
      itc->itc_row_key = itc->itc_insert_key = (*buf_ret)->bd_tree->it_key;
      itc_commit_delete (itc, buf_ret);
      if (*buf_ret != buf_from)
	return PAGE_DELETED;
      return PAGE_UPDATED | (is_first ? LEAF_CHG_MASK : 0);
    }
  else if (IE_ISSET (page + pos, IEF_UPDATE))
    {
      int row_end;
      int new_len;
      dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, SHORT_REF (page + pos + IE_KEY_ID));
      if (key->key_is_bitmap)
	itc_invalidate_bm_crs (itc, *buf_ret, 0, NULL); /* can be registered on rc pre-images. */
      l = row_reserved_length (page + pos, key);
      new_len = row_length (page + pos, key);
      row_end = pos + l;

      IE_SET_FLAGS (page + pos, 0);
      buf->bd_content_map->pm_bytes_free += (short) (ROW_ALIGN (l) - ROW_ALIGN (new_len));
      return PAGE_UPDATED;
    }
  return PAGE_NOT_CHANGED;
}


void
pl_finalize_absent (page_lock_t * pl, it_cursor_t * itc)
{
  buffer_desc_t decoy;
  it_map_t * itm = IT_DP_MAP (pl->pl_it, pl->pl_page);
  dp_addr_t dp = pl->pl_page;
  index_tree_t * tree = pl->pl_it;
  memset (&decoy, 0, sizeof (buffer_desc_t));
  decoy.bd_being_read = 1;
  BD_SET_IS_WRITE (&decoy, 1);
  sethash (DP_ADDR2VOID (pl->pl_page), &itm->itm_dp_to_buf, (void*) &decoy);
  ITC_LEAVE_MAP_NC (itc);
  pl_release (pl, itc->itc_ltrx, NULL);
  /* note that from now on pl can be free */
  ITC_IN_KNOWN_MAP (itc, dp);
  if (decoy.bd_read_waiting || decoy.bd_write_waiting)
    {
      buffer_desc_t * buf;
      dp_addr_t phys_dp;
      IT_DP_REMAP (tree, dp, phys_dp);
      ITC_LEAVE_MAP_NC (itc);
      TC (tc_read_absent_while_finalize);
      buf = bp_get_buffer (NULL, BP_BUF_REQUIRED);
      buf->bd_being_read = 1;
      buf->bd_page = dp;
      buf->bd_storage = tree->it_storage;
      buf->bd_physical_page = phys_dp;
      BD_SET_IS_WRITE (buf, 1);
      buf->bd_readers = 0;
      buf->bd_write_waiting = NULL;
      buf->bd_tree = tree;
      buf_disk_read (buf);
      ITC_IN_KNOWN_MAP (itc, dp);
      sethash (DP_ADDR2VOID (dp), &itm->itm_dp_to_buf, (void*) buf);
      buf->bd_pl = (page_lock_t *) gethash (DP_ADDR2VOID (dp), &itm->itm_locks);
      DBG_PT_READ (buf, itc->itc_ltrx);
      buf->bd_being_read = 0;
      buf->bd_readers = decoy.bd_readers;
      BD_SET_IS_WRITE (buf, decoy.bd_is_write);
      buf->bd_read_waiting = decoy.bd_read_waiting;
      buf->bd_write_waiting = decoy.bd_write_waiting;
      /* this thread has read the buffer and will now leave to let the waiting in */
      page_mark_change (buf, RWG_WAIT_DISK);
      page_leave_inner (buf);
      ITC_LEAVE_MAP_NC (itc);
    }
  else 
    {
      remhash (DP_ADDR2VOID (dp), &itm->itm_dp_to_buf);
      ITC_LEAVE_MAP_NC (itc);
    }
}


void
pl_finalize_page (page_lock_t * pl, it_cursor_t * itc)
{
  int change = PAGE_NOT_CHANGED, rc, change_leaf_ptr = 0;
  lock_trx_t *lt = itc->itc_ltrx;
  buffer_desc_t *buf = NULL;
  if (DP_DELETED == pl->pl_page)
    {
      TC (tc_release_pl_on_deleted_dp);
      pl_release (pl, lt, NULL);
      return;
    }

  if (!PL_IS_FINALIZE (pl))
    {
      /* if it is absent and needs no finalize, do not read it if not needed. * butmake a decoy for it, as if it was being read.  And if somebody comes in on the decoy, then must actually read the page, so that this looks like a 2nd in read for the thread that waits on the decoy.  If none waits, do not read */
      it_map_t * itm;
      ITC_IN_KNOWN_MAP (itc, pl->pl_page);
      itm = IT_DP_MAP (pl->pl_it, pl->pl_page);
      if (DP_DELETED != pl->pl_page && !PL_IS_FINALIZE (pl) && !(buf = gethash (DP_ADDR2VOID (pl->pl_page), &itm->itm_dp_to_buf)))
	{
	  pl_finalize_absent (pl, itc);
      return;
    }
    }
  do
    {
      if (DP_DELETED == pl->pl_page)
	{
	  TC (tc_release_pl_on_deleted_dp);
	  ITC_LEAVE_MAPS (itc);
	  pl_release (pl, lt, NULL);
	  return;
	}
      ITC_IN_KNOWN_MAP (itc, pl->pl_page);
      page_wait_access (itc, pl->pl_page, NULL, &buf, PA_WRITE, RWG_WAIT_KEY);
    }
  while (itc->itc_to_reset > RWG_WAIT_KEY);

  if (PF_OF_DELETED == buf)
    {
      /* check needed here because the page could have gone out during the above wait and the wait itself could give 'a no wait status with bad timing  The page map does not serialize the whole delete as atomic. */
      TC (tc_release_pl_on_deleted_dp);
      ITC_LEAVE_MAPS (itc);
      pl_release (pl, lt, NULL);
      return;
    }

  itc->itc_page = pl->pl_page;
  if (PL_IS_PAGE (pl))
    {
      int pos = SHORT_REF (buf->bd_buffer + DP_FIRST);
      while (pos)
	{
	  int next_pos = IE_NEXT (buf->bd_buffer + pos);
	  rc = itc_finalize_row (itc, &buf, pos);
	  change_leaf_ptr |= rc & LEAF_CHG_MASK;
	  rc = rc & ~LEAF_CHG_MASK; 
	  change = MAX (change, rc);
	  if (PAGE_DELETED == change)
	    break;
	  pos = next_pos;
	}
    }
  else
    {
      if (pl->pl_n_row_locks > buf->bd_content_map->pm_count)
	GPF_T1 ("more locks than rows");
      DO_RLOCK (rl, pl)
      {
	if (rl->pl_owner == lt)
	  {
	    rc = itc_finalize_row (itc, &buf, rl->rl_pos);
	    change_leaf_ptr |= rc & LEAF_CHG_MASK;
	    rc = rc & ~LEAF_CHG_MASK; 
	    change = MAX (change, rc);
	    if (PAGE_DELETED == change)
	      goto rls_done;	/* no break, DO_RLOCKS is 2 nested loops */
	  }
      }
      END_DO_RLOCK;
    rls_done:;
    }

  if (change != PAGE_NOT_CHANGED
      && !PL_IS_FINALIZE (pl))
    {
      log_error ("Dirty row without transaction on %d.\n", buf->bd_page);
      dbg_page_map (buf);
      /* GPF_T1 ("Finalize flag not set on page lock"); */
      /* autorepair if page was in checkpoint, make it a delta */
    }
  if (change != PAGE_DELETED && change_leaf_ptr)
    {
      pl_release (pl, lt, buf);
      itc->itc_row_key = itc->itc_insert_key = buf->bd_tree->it_key;
      itc_fix_leaf_ptr (itc, buf);
      return;
    }
  pl_release (pl, lt, buf);
  ITC_IN_KNOWN_MAP (itc, itc->itc_page);
  if (change == PAGE_UPDATED)
    buf_set_dirty_inside (buf);
  if (change != PAGE_NOT_CHANGED)
    page_mark_change (buf, change == PAGE_UPDATED ? RWG_WAIT_KEY : RWG_WAIT_SPLIT);
  page_leave_inner (buf);
  ITC_LEAVE_MAP_NC (itc);
}


int
itc_rollback_row (it_cursor_t * itc, buffer_desc_t ** buf_ret, int pos, row_lock_t * was_rl,
		  page_lock_t * pl)
{
  int bytes_left;
  buffer_desc_t *buf = *buf_ret;
  lock_trx_t *lt = itc->itc_ltrx;
  buffer_desc_t *buf_from = buf;
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
      if (RB_INSERT == rbe->rbe_op)
	{
	  int is_first = itc->itc_position == SHORT_REF (page + DP_FIRST);
	  itc->itc_row_key = itc->itc_insert_key = (*buf_ret)->bd_tree->it_key;
	  itc_commit_delete (itc, buf_ret);
	  if (was_rl)
	    was_rl->rl_pos = 0;
	  if (*buf_ret != buf_from)
	    return PAGE_DELETED;
	  return PAGE_UPDATED | (is_first ? LEAF_CHG_MASK : 0);
	}
      else
	{
	  short prev_next = IE_NEXT (page + pos);
	  if (buf->bd_tree->it_key->key_is_bitmap)
	    itc_invalidate_bm_crs (itc, *buf_ret, 0, NULL); /** can be registered based on after image that is no longer valid */
	  l = row_reserved_length (page + pos, buf->bd_tree->it_key);
	  if (rbe->rbe_row_len > ROW_ALIGN (l))
	    GPF_T1 ("Space for row is shorter than pre-image");
	  memcpy (page + pos,
		  rbe->rbe_string + rbe->rbe_row,
		  rbe->rbe_row_len);
	  IE_SET_FLAGS (page + pos, 0);
	  IE_SET_NEXT (page + pos, prev_next);
	  bytes_left =  ROW_ALIGN (l) - ROW_ALIGN (rbe->rbe_row_len);
	  if (bytes_left)
	    {
	      buf->bd_content_map->pm_bytes_free += bytes_left;
	    }
	}
      return PAGE_UPDATED;
    }
  return PAGE_NOT_CHANGED;
}


void
pl_rollback_page (page_lock_t * pl, it_cursor_t * itc)
{
  int change = PAGE_NOT_CHANGED, rc, change_leaf_ptr = 0;
  lock_trx_t *lt = itc->itc_ltrx;
  buffer_desc_t *buf = NULL;
  ITC_IN_KNOWN_MAP (itc, pl->pl_page);

  if (DP_DELETED == pl->pl_page)
    {
      ITC_LEAVE_MAP_NC (itc);
      TC (tc_release_pl_on_deleted_dp);
      pl_release (pl, lt, NULL);
      return;
    }


  if (buf && buf->bd_being_read)
    TC (tc_finalize_while_being_read);


  do
    {
      ITC_IN_KNOWN_MAP (itc, pl->pl_page);
      if (DP_DELETED == pl->pl_page)
	{
	  TC (tc_release_pl_on_deleted_dp);
	  ITC_LEAVE_MAPS (itc);
	  pl_release (pl, lt, NULL);
	  return;
	}
      page_wait_access (itc, pl->pl_page, NULL, &buf, PA_WRITE, RWG_WAIT_KEY);
    }
  while (itc->itc_to_reset > RWG_WAIT_KEY);

  if (PF_OF_DELETED == buf)
    {
      /* check needed here because the page could have gone out during the above wait and the wait itself could give 'a no wait status with bad timing  The page map does not serialize the whole delete as atomic. */
      TC (tc_release_pl_on_deleted_dp);
      ITC_LEAVE_MAPS (itc);
      pl_release (pl, lt, NULL);
      return;
    }

  itc->itc_page = pl->pl_page;
  if (PL_IS_PAGE (pl))
    {
      int pos = SHORT_REF (buf->bd_buffer + DP_FIRST);
      while (pos)
	{
	  int next_pos = IE_NEXT (buf->bd_buffer + pos);
	  rc = itc_rollback_row (itc, &buf, pos, NULL, pl);
	  change_leaf_ptr |= rc & LEAF_CHG_MASK;
	  rc = rc & ~LEAF_CHG_MASK; 
	  change = MAX (change, rc);
	  if (PAGE_DELETED == change)
	    break;
	  pos = next_pos;
	}
    }
  else
    {
      DO_RLOCK (rl, pl)
      {
	if (rl->pl_owner == lt)
	  {
	    rc = itc_rollback_row (itc, &buf, rl->rl_pos, rl, pl);
	    change_leaf_ptr |= rc & LEAF_CHG_MASK;
	    rc = rc & ~LEAF_CHG_MASK; 
	    change = MAX (change, rc);
	    if (PAGE_DELETED == change)
	      goto rls_done;	/* not break, DO_RLOCKS is 2 nested loops */
	  }
      }
      END_DO_RLOCK;
    rls_done:;
    }
  if (change != PAGE_DELETED && change_leaf_ptr)
    {
      pl_release (pl, lt, buf);
      itc->itc_row_key = itc->itc_insert_key = buf->bd_tree->it_key;
      itc_fix_leaf_ptr (itc, buf);
      return;
    }
  pl_release (pl, lt, buf);
  ITC_IN_KNOWN_MAP (itc, itc->itc_page);
  if (change == PAGE_UPDATED)
    buf_set_dirty_inside (buf);
  if (change != PAGE_NOT_CHANGED)
    page_mark_change (buf, change == PAGE_UPDATED ? RWG_WAIT_KEY : RWG_WAIT_SPLIT);
  page_leave_inner (buf);
  ITC_LEAVE_MAP_NC (itc);
}


void
lt_blob_transact (it_cursor_t * itc, int op)
{
  lock_trx_t *lt = itc->itc_ltrx;
  dk_hash_t *dirt = lt->lt_dirty_blobs;
  if (NULL != dirt)
    {
      dk_hash_iterator_t current_blob;
      void *key, *data;
      if (lt->lt_is_excl)
	op = SQL_COMMIT; /* for an atomic mode txn, rollback is commit since no rb records kept.  So if blobs are del'd refs are not, so do as if commit no matter what and things will be consistent. */
      dk_hash_iterator (&current_blob, dirt);
      while (dk_hit_next (&current_blob, &key, &data))
	{
	  blob_layout_t *bl = (blob_layout_t *)(data);
	  if (bl->bl_delete_later & ((op == SQL_COMMIT) ? BL_DELETE_AT_COMMIT : BL_DELETE_AT_ROLLBACK))
	    blob_chain_delete (itc, bl);
	  else blob_layout_free (bl); /* there was dk_free_box ((box_t)bl);*/
	}
      hash_table_free(dirt);
      lt->lt_dirty_blobs = NULL;
    }
}

void
lt_wait_until_dead (lock_trx_t * lt)
{
  du_thread_t *thr = THREAD_CURRENT_THREAD;
  ASSERT_IN_TXN;
  TC (tc_wait_trx_self_kill);
  dk_set_push (&lt->lt_wait_end, (void *) thr);
  if (!lt->lt_threads) GPF_T1 ("can't wait for self kill of a txn with no thread inside");
  rdbg_printf (("Wait for transact of %s T=%p\n", LT_NAME (lt), lt));
  LEAVE_TXN;
/*  rdbg_printf (("Wait for transact of %s T=%ld\n", LT_NAME (lt), TRX_NO (lt))); */
  semaphore_enter (thr->thr_sem);
  IN_TXN;
}



#define BAD_LOCK \
  printf ("*** Unowned lock T=%ld L=%d ROW=%d \n", \
	      lt->lt_trx_no, dp, pos)

#define BAD_PRE_LOCK \
  printf ("*** Unowned before transact T=%ld L=%d ROW=%d \n", \
	      lt->lt_trx_no, dp, pos)


#ifdef PAGE_TRACE
void
lock_check_owners (gen_lock_t * lock, lock_trx_t * lt,
		   dp_addr_t dp, int pos, page_lock_t * pl, int is_precheck)
{
  it_cursor_t * waiting;
  if (!lock->pl_is_owner_list)
    {
      lock_trx_t * owner = lock->pl_owner;
      if (owner == lt)
	{
	  if (is_precheck)
	    {
	      if (!dk_set_member (lt->lt_locks, (void*) pl))
		BAD_PRE_LOCK;
	    }
	  else
	    BAD_LOCK;
	}
      else
	{
	  if (!dk_set_member (owner->lt_locks, (void*) pl))
	    {
	      if (owner->lt_status == LT_CLOSING)
		printf ("--- lock of blown off T=%ld L=%d ROW=%d \n",
			TRX_NO (owner), dp, pos);
	      else
		printf ("*** unowned lock of other T=%ld ST=%d L=%d ROW=%d \n",
			TRX_NO (owner), (int) owner->lt_status, dp, pos);
	    }
	}
    }
  else
    {
      dk_set_t l = (dk_set_t) lock->pl_owner;
      DO_SET (lock_trx_t *, owner, &l)
	{
	  if (owner == lt)
	    {
	      if (is_precheck)
		{
		  if (!dk_set_member (lt->lt_locks, (void*) pl))
		    BAD_PRE_LOCK;
		}
	      else
		BAD_LOCK;
	    }
	  else
	    {
	      if (!dk_set_member (owner->lt_locks, (void*) pl))
		{
		  if (owner->lt_status == LT_CLOSING)
		    printf ("--- lock of blown off T=%ld L=%d ROW=%d \n",
			    TRX_NO (owner), dp, pos);
		  else
		    printf ("*** unowned lock of other T=%ld ST=%d L=%d ROW=%d \n",
			    TRX_NO (owner), (int) owner->lt_status, dp, pos);
		  }
	    }
	}
      END_DO_SET();
    }
  if (is_precheck)
    return;
  waiting = lock->pl_waiting;
  while (waiting)
    {
      if (waiting->itc_ltrx == lt)
	printf ("*** Bad wait T=%ld L=%ld ROW=%d \n",
		lt->lt_trx_no, dp, pos);
      waiting = waiting->itc_next_on_lock;
    }
  if (pl->pl_is_owner_list)
    {

    }
}


void
lt_check_stray_locks (lock_trx_t * lt, int is_precheck)
{
#if 0
  long dp;
  page_lock_t * pl;
  dk_hash_iterator_t hit;
  ASSERT_IN_MAP;
  dk_hash_iterator (&hit, db_main_tree->it_locks);
  while (dk_hit_next (&hit, (void**) &dp, (void**) &pl))
    {
      if (PL_IS_PAGE (pl))
	{
	  lock_check_owners ((gen_lock_t *) pl, lt, dp, 0, pl, is_precheck);
	}
      else
	{
	  DO_RLOCK (rl, pl)
	    {
	      lock_check_owners ((gen_lock_t*) rl, lt, dp, rl->rl_pos, pl, is_precheck);
	    }
	  END_DO_RLOCK;
	}
    }
#endif
}
#endif /* PAGE_TRACE */


void
lt_resume_waiting_end (lock_trx_t * lt)
{
  ASSERT_IN_TXN;
    DO_SET (du_thread_t *, waiting, &lt->lt_wait_end)
  {
    rdbg_printf (("release lock release wait on %s\n", LT_NAME (lt)));
    semaphore_leave (waiting->thr_sem);
  }
  END_DO_SET ();
  dk_set_free (lt->lt_wait_end);
  lt->lt_wait_end = NULL;

}

dp_addr_t 
pl_page_key (page_lock_t * pl)
{
  return pl->pl_page;
}


page_lock_t ** 
lt_locks_to_array (lock_trx_t * lt, page_lock_t ** arr, int max, int * fill_ret)
{
  /* If they all fit, put them there without sort.  If a lot, alloc a new array. If more than 1/4 of buffers, also sort */
  dk_hash_t * locks = &lt->lt_lock;
  int n_locks = locks->ht_count, fill = 0, inx;
  page_lock_t * pl;
  void* d;
  dk_hash_iterator_t hit;
  if (n_locks > max)
    {
      max = MIN (n_locks, 1000000);
      arr = dk_alloc (sizeof (caddr_t) * max );
    }
  mutex_enter (&lt->lt_locks_mtx);
  dk_hash_iterator (&hit, locks);
    while (dk_hit_next (&hit, (void**)&pl, &d))
    {
      arr[fill++] = pl;
      if (fill == max)
	break;
    }
  if (max != n_locks)
    {
      for (inx = 0; inx < fill; inx++)
	remhash ((void*)arr[inx], locks);
    }
  else 
    clrhash (locks);
  mutex_leave (&lt->lt_locks_mtx);
  if (max > main_bufs / 4)
    {
      buf_sort ((buffer_desc_t **)arr, fill, (sort_key_func_t)pl_page_key);
    }
  *fill_ret = fill;
  return arr;
}


void
lt_transact (lock_trx_t * lt, int op)
{
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  page_lock_t * pl_arr_auto[100];
  page_lock_t ** pl_arr;
  ASSERT_IN_TXN;
  if (lt->lt_threads != lt->lt_lw_threads + lt->lt_close_ack_threads + lt->lt_vdb_threads)
    {
      lt_log_debug ((
	  "mismatched thread counts in lt_transact : "
	  "lt=%p lt_threads=%d lt_lw_threads=%d lt_close_ack_threads=%d lt_vdb_threads=%d",
	  lt, lt->lt_threads, lt->lt_lw_threads, lt->lt_close_ack_threads, lt->lt_vdb_threads));
      GPF_T1 ("mismatched lt thread counts in lt_transact");
    }

  lt->lt_timeout = 0; /* make sure no 2 kills because of timeout detectedby reaper. */
  if (LT_DELTA_ROLLED_BACK == lt->lt_status)
    return;
  if (LT_CLOSING == lt->lt_status)
    {
      lt_wait_until_dead (lt);
      return;
    }
  lt_clear_waits (lt);
  DBG_PT_PRINTF (("  %s T=%d\n", op == SQL_COMMIT ? "  RL Commit" : "RL Rollback", lt->lt_trx_no));
  if (DO_LOG(LOG_TRANSACT))
    {
      char from[16];
      char user[16];
      char peer[32];
      dks_client_ip (lt->lt_client, from, user, peer, sizeof (from), sizeof (user), sizeof (peer));
      log_info ("LTRS_1 %s %s %s %s transact %p %li", user, from, peer,
	  op == SQL_COMMIT ? "Commit" : "Rollback", lt,
          lt->lt_client ? lt->lt_client->cli_autocommit : 0);
    }
  lt->lt_status = LT_CLOSING;
#ifdef PAGE_TRACE
  lt_check_stray_locks (lt, 1);
#endif
  LEAVE_TXN;
  ITC_INIT (itc, NULL, lt);
  lt_hi_transact (lt, op);
  for (;;)
    {
      int n_locks, l_fill, l_inx;
      pl_arr = lt_locks_to_array (lt, pl_arr_auto, sizeof (pl_arr_auto) / sizeof (caddr_t), &l_fill);
      n_locks = lt->lt_lock.ht_count;
      for (l_inx = 0; l_inx < l_fill; l_inx++)
      {
	  page_lock_t * pl = pl_arr[l_inx];
	itc->itc_tree = pl->pl_it;
	if (SQL_COMMIT == op)
	  pl_finalize_page (pl, itc);
	else
	  pl_rollback_page (pl, itc);
	ITC_LEAVE_MAPS (itc);
      }
      if (pl_arr != (page_lock_t**) &pl_arr_auto)
	dk_free ((caddr_t)pl_arr, -1);
      IN_LT_LOCKS (lt);
      if (0 == lt->lt_lock.ht_count)
	break;
      if (n_locks != lt->lt_lock.ht_count)
      TC (tc_split_while_committing);
      LEAVE_LT_LOCKS (lt);
    }
  LEAVE_LT_LOCKS (lt);
  lt_free_rb (lt);
  lt_blob_transact (itc, op);
  IN_TXN;
  if (lt->lt_waiting_for_this)
    {
      GPF_T1 ("txn wait edges can't appear on a closing txn");
    }

  while (lt->lt_threads > lt->lt_close_ack_threads + lt->lt_vdb_threads)
    {
      rdbg_printf (("close acknowledge wait of T=%ld\n", (long) TRX_NO (lt)));
      LEAVE_TXN;
      PROCESS_ALLOW_SCHEDULE ();
      IN_TXN;
    }
#ifdef PAGE_TRACE
  lt_check_stray_locks (lt, 0);
#endif
  lt_clear_waits (lt);
  lt->lt_status = LT_DELTA_ROLLED_BACK;
  ASSERT_IN_TXN;
  lt->lt_lw_threads = 0;
  LT_CLOSE_ACK_THREADS(lt);
  lt->lt_close_ack_threads = 0;
  lt_resume_waiting_end (lt);
#ifdef VIRTTP
  if (lt->lt_2pc._2pc_info)
    {
      tp_dtrx_t * tp_dtrx = lt->lt_2pc._2pc_info;
      tp_dtrx->vtbl->commit_2 (tp_dtrx->dtrx_info, op == SQL_COMMIT);
      virt_tp_store_connections (lt);
      tp_dtrx->vtbl->dealloc (tp_dtrx);
      lt->lt_2pc._2pc_info = 0;
    }
#endif
  DBG_PT_PRINTF (("  Transacted T=%d\n", lt->lt_trx_no));
  /* it_cache_check (db_main_tree); */
}


db_buf_t
rbp_allocate (void)
{
  return ((db_buf_t) dk_alloc (PAGE_DATA_SZ));
}

void
rbp_free (caddr_t p)
{
  dk_free (p, PAGE_DATA_SZ);
}

resource_t *rb_page_rc;


uint32
key_hash_cols (db_buf_t row, dbe_key_t * key, dbe_col_loc_t * cl, uint32 code)
{
  db_buf_t row_data = row + IE_FIRST_KEY;
  int inx;
  for (inx = 0; cl[inx].cl_col_id; inx++)
    {
      int off, len;
      KEY_COL (key, row_data, cl[inx], off, len);
      if (cl[inx].cl_sqt.sqt_dtp == DV_LONG_INT)
	{
	  int32 v = LONG_REF (row_data + off);
	  if (v)
	    code = (code * v) ^ (code >> 23);
	  else
	    code = code << 2 | code >> 30;
	}
      else
	{
	  int inx2;
	  for (inx2 = 0; inx2 < len; inx2++)
	    {
	      uint32 b = row_data[off + inx2];
	      code = ((code * (b + 3)) + 123) ^ (code >> 24);
	    }
	}
    }
  return code;
}


int
key_hash_eq (db_buf_t row1, db_buf_t row2, dbe_key_t * key1, dbe_key_t * key2,
	      dbe_col_loc_t * cl1, dbe_col_loc_t * cl2)
{
  int inx;
  row1 += IE_FIRST_KEY;
  row2 += IE_FIRST_KEY;
  for (inx = 0; cl1[inx].cl_col_id; inx++)
    {
      int off1, off2, len1, len2;
      KEY_COL (key1, row1, cl1[inx], off1, len1);
      KEY_COL (key2, row2, cl2[inx], off2, len2);
      if (len1 != len2)
	return 0;
      if (0 != memcmp (row1 + off1, row2 + off2, len1))
	return 0;
    }
  return 1;
}


int
rb_entry_eq (db_buf_t row1, db_buf_t row2)
{
  dbe_key_t * key1 = sch_id_to_key (wi_inst.wi_schema, SHORT_REF (row1 + IE_KEY_ID));
  dbe_key_t * key2 = sch_id_to_key (wi_inst.wi_schema, SHORT_REF (row2 + IE_KEY_ID));
  if (key1->key_super_id != key2->key_super_id)
    return 0;
  if (key1->key_key_fixed
      && !key_hash_eq (row1, row2, key1, key2, key1->key_key_fixed, key2->key_key_fixed))
    return 0;
  if (key1->key_key_var
      && !key_hash_eq (row1, row2, key1, key2, key1->key_key_var, key2->key_key_var))
    return 0;
  return 1;
}


rb_entry_t *
lt_rb_entry (lock_trx_t * lt, db_buf_t row, long *code_ret, rb_entry_t ** prev_ret, int leave_mtx)
{
  key_id_t key_id = SHORT_REF (row + IE_KEY_ID);
  dbe_key_t * key;
  int32 rb_code;
  rb_entry_t *rbe;
  if (KI_LEFT_DUMMY == key_id)
    return NULL;
  key = sch_id_to_key (wi_inst.wi_schema, key_id);
  rb_code = key_hash_cols (row, key, key->key_key_fixed, HC_INIT);
  rb_code = key_hash_cols (row, key, key->key_key_var, rb_code);
  mutex_enter (&lt->lt_rb_mtx);
  rbe = (rb_entry_t *) gethash ((void *) (ptrlong) rb_code, lt->lt_rb_hash);
  if (code_ret)
    *code_ret = rb_code;
  if (prev_ret)
    *prev_ret = rbe;
  while (rbe)
    {
      if (!rbe->rbe_string)
	GPF_T1 ("rbe paged out");

      if (rb_entry_eq (row, rbe->rbe_string + rbe->rbe_row))
	{
	  if (leave_mtx)
	    mutex_leave (&lt->lt_rb_mtx);
	return rbe;
	}
      rbe = rbe->rbe_next;
    }
  if (leave_mtx)
    mutex_leave (&lt->lt_rb_mtx);
  return NULL;
}


void
lt_rb_new_entry (lock_trx_t * lt, long rb_code, rb_entry_t * prev,
		 db_buf_t ent, short ent_len, char op)
{
  NEW_VARZ (rb_entry_t, rbe);
  ent_len = ROW_ALIGN (ent_len);
  ASSERT_IN_MTX (&lt->lt_rb_mtx);
  if (!prev)
    sethash ((void *) (ptrlong) rb_code, lt->lt_rb_hash, (void *) (ptrlong) rbe);
  else
    {
      TC (tc_rb_code_non_unique);
      rbe->rbe_next = prev->rbe_next;
      prev->rbe_next = rbe;
    }
  if (!lt->lt_rb_page || lt->lt_rbp_fill + ent_len > PAGE_DATA_SZ)
    {
      lt->lt_rb_page = (db_buf_t) resource_get (rb_page_rc);
      lt->lt_rbp_fill = 0;
      dk_set_push (&lt->lt_rb_pages, (void *) lt->lt_rb_page);
    }
  rbe->rbe_string = lt->lt_rb_page;
  rbe->rbe_row = lt->lt_rbp_fill;
  rbe->rbe_row_len = ent_len;
  rbe->rbe_op = op;
  memcpy (lt->lt_rb_page + lt->lt_rbp_fill, ent, ent_len);
  lt->lt_rbp_fill += ent_len;
}


void
lt_rb_insert (lock_trx_t * lt, db_buf_t row)
{
  long rb_code, key_len;
  rb_entry_t *prev;
  rb_entry_t *rbe;
  if (lt->lt_is_excl)
    return;
  rbe = lt_rb_entry (lt, row, &rb_code, &prev, 0);
  if (!rbe)
    {
      key_len = row_length (row, sch_id_to_key (wi_inst.wi_schema, SHORT_REF (row + IE_KEY_ID)));
      lt_rb_new_entry (lt, rb_code, prev, row, (short) key_len, RB_INSERT);
    }
  mutex_leave (&lt->lt_rb_mtx);
}


void
lt_no_rb_insert (lock_trx_t * lt, db_buf_t row)
{
  /* remove the rb entry to make aninsert irreversible in mid transaction */
  rb_entry_t * prev;
  long rb_code;
  rb_entry_t *rbe;
  if (lt->lt_is_excl)
    return;
  rbe = lt_rb_entry (lt, row, &rb_code, &prev, 0);
  if (!rbe)
    GPF_T1 ("no rb entry when removing insert rb entry");
  prev = (rb_entry_t *)gethash ((void*)(ptrlong)rb_code, lt->lt_rb_hash);
  if (prev == rbe)
    sethash ((void*)(ptrlong)rb_code, lt->lt_rb_hash, (void*)rbe->rbe_next);
  else
    {
      rb_entry_t *prev_in_list = prev;
      prev = prev->rbe_next;
      while (prev)
	{
	  if (rbe == prev)
	    {
	      prev_in_list->rbe_next = rbe->rbe_next;
	      goto end;
	    }
	  prev_in_list =prev;
	  prev = prev->rbe_next;
	}
      GPF_T1("rbe ent not found in rem rb entry");
    }
 end:
  mutex_leave (&lt->lt_rb_mtx);
  dk_free ((caddr_t) rbe, sizeof (rb_entry_t));
}



void
lt_rb_update (lock_trx_t * lt, db_buf_t row)
{
  int row_len;
  long rb_code;
  rb_entry_t *prev;
  rb_entry_t *rbe = lt_rb_entry (lt, row, &rb_code, &prev, 0);
  if (!rbe)
    {
      row_len = row_length (row, sch_id_to_key (wi_inst.wi_schema, SHORT_REF (row + IE_KEY_ID)));
      lt_rb_new_entry (lt, rb_code, prev, row, row_len, RB_UPDATE);
    }
  mutex_leave (&lt->lt_rb_mtx);
}



void
lt_free_rb (lock_trx_t * lt)
{
  rb_entry_t *rbe;
  caddr_t k;
  dk_hash_iterator_t hit;
  if (0 == lt->lt_rb_hash->ht_count)
    return;
  DO_SET (db_buf_t, page, &lt->lt_rb_pages)
  {
    resource_store (rb_page_rc, (void *) page);
  }
  END_DO_SET ();
  dk_set_free (lt->lt_rb_pages);
  lt->lt_rb_pages = NULL;
  dk_hash_iterator (&hit, lt->lt_rb_hash);
  while (dk_hit_next (&hit, (void **) &k, (void **) &rbe))
    {
      while (rbe)
	{
	  rb_entry_t *next = rbe->rbe_next;
	  dk_free ((caddr_t) rbe, sizeof (rb_entry_t));
	  rbe = next;
	}
    }
  if (lt->lt_rb_hash->ht_actual_size > 140)
    {
      hash_table_free (lt->lt_rb_hash);
      lt->lt_rb_hash = hash_table_allocate (101);
    }
  else
    clrhash (lt->lt_rb_hash);
}

