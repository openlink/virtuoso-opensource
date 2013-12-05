/*
 *  Dkbasket.c
 *
 *  $Id$
 *
 *  Baskets
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

#include "Dk.h"

#if defined (WIN32) || defined (SOLARIS)
#define __builtin_prefetch(m)
#endif

void
basket_init (basket_t * bsk)
{
  LISTINIT (bsk, bsk_next, bsk_prev);
  bsk->bsk_count = 0;
}


void
basket_add (basket_t * bsk, void *token)
{
  NEW_VAR (basket_t, newn);

  if (bsk->bsk_count == 0)
    basket_init (bsk);

  newn->bsk_pointer = token;
  LISTPUTBEFORE (bsk, newn, bsk_next, bsk_prev);
  bsk->bsk_count++;
}


void
mp_basket_add (mem_pool_t * mp, basket_t * bsk, void *token)
{
  basket_t *newn = (basket_t *) mp_alloc (mp, sizeof (basket_t));
  if (bsk->bsk_count == 0)
    basket_init (bsk);

  newn->bsk_pointer = token;
  LISTPUTBEFORE (bsk, newn, bsk_next, bsk_prev);
  bsk->bsk_count++;
}


void *
basket_peek (basket_t * bsk)
{
  return (bsk->bsk_count == 0) ? NULL : bsk->bsk_next->bsk_pointer;
}


void *
basket_get (basket_t * bsk)
{
  void *data;

#ifdef MTX_DEBUG
  if (bsk->bsk_req_mtx)
    ASSERT_IN_MTX (bsk->bsk_req_mtx);
#endif
  if (bsk->bsk_count == 0)
    return NULL;

  bsk->bsk_count--;
  bsk = bsk->bsk_next;

  LISTDELETE (bsk, bsk_next, bsk_prev);

  data = bsk->bsk_pointer;
  dk_free (bsk, sizeof (basket_t));

  return data;
}


void *
basket_first (basket_t * bsk)
{
  if (bsk->bsk_count == 0)
    return NULL;
  return bsk->bsk_next->bsk_pointer;
}


void *
mp_basket_get (basket_t * bsk)
{
  void *data;

  if (bsk->bsk_count == 0)
    return NULL;

  bsk->bsk_count--;
  bsk = bsk->bsk_next;

  LISTDELETE (bsk, bsk_next, bsk_prev);

  data = bsk->bsk_pointer;

  return data;
}


int
basket_is_empty (basket_t * bsk)
{
  return bsk->bsk_count == 0;
}


void *
basket_remove_if (basket_t * bsk, basket_check_t f, void *cd)
{
  int found = 0;
  void *remd = NULL;
  dk_set_t tmp = NULL;
  void *elt;
#ifdef MTX_DEBUG
  if (bsk->bsk_req_mtx)
    ASSERT_IN_MTX (bsk->bsk_req_mtx);
#endif

  while ((elt = basket_get (bsk)))
    {
      if (!found && f (elt, cd))
	{
	  remd = elt;
	  found = 1;
	}
      else
	dk_set_push (&tmp, elt);
    }
  dk_set_nreverse (tmp);
  DO_SET (void *, x, &tmp)
  {
    basket_add (bsk, x);
  }
  END_DO_SET ();
  dk_set_free (tmp);
  return remd;
}





void
rb_ck_cnt (rbuf_t * rb)
{
  rbuf_elt_t * elt, *prev = NULL;
  int ctr = 0;
  if (0 == rb->rb_count)
    {
      if (rb->rb_first != rb->rb_last) GPF_T1 ("bad rb");
      if (rb->rb_first && (rb->rb_first->rbe_next || rb->rb_first->rbe_count)) GPF_T1 ("bad rbe");
    }
  for (elt = rb->rb_first; elt; elt = elt->rbe_next)
    {
      if (elt->rbe_prev != prev) GPF_T1 ("bad rb");
      ctr += elt->rbe_count;
      if (0 == elt->rbe_count && (elt != rb->rb_first || elt->rbe_next)) GPF_T1 ("bad rb");
      prev = elt;
      if (elt == rb->rb_last && elt->rbe_next) GPF_T1 ("bad rb");
    }
  if (ctr != rb->rb_count) GPF_T1 ("bad rb");
}

int rbe_alloc_ctr;
int rbe_free_ctr;

#ifdef MALLOC_DEBUG
#define RBUF_DEBUG
#endif

#ifdef RBUF_DEBUG
#define RB_CK_CNT(rb) \
  rb_ck_cnt (rb);
#define RBUF_TC(ctr) ctr++;
#else
#define RB_CK_CNT(rb)
#define RBUF_TC(ctr)
#endif


void
rbuf_add (rbuf_t * rb, void* elt)
{
  int next;
  rbuf_elt_t * rbe = rb->rb_last;
  if (rb->rb_add_cb)
    rb->rb_add_cb (rb, elt);
  if (!rbe)
    {
      rbe = (rbuf_elt_t*)dk_alloc (sizeof (rbuf_elt_t));
      RBUF_TC (rbe_alloc_ctr);
      memzero (rbe, sizeof (rbuf_elt_t));
      rb->rb_first = rb->rb_last = rbe;
      next = 1;
    }
  else if ((next = RBE_NEXT (rbe, rbe->rbe_write)) == rbe->rbe_read)
    {
      rbuf_elt_t * new_rbe;
      if (!rbe->rbe_data[rbe->rbe_read])
	{
	  rbe->rbe_read = RBE_NEXT (rbe, rbe->rbe_read);
	}
      else
	{
	  new_rbe = (rbuf_elt_t*)dk_alloc (sizeof (rbuf_elt_t));
	  RBUF_TC (rbe_alloc_ctr);
	  memzero (new_rbe, sizeof (rbuf_elt_t));
	  L2_INSERT_AFTER (rb->rb_first, rb->rb_last, rb->rb_last, new_rbe, rbe_);
	  rbe = new_rbe;
	  next = 1;
	}
    }
  rbe->rbe_data[rbe->rbe_write] = elt;
  rbe->rbe_write = next;
  rbe->rbe_count++;
  rb->rb_count++;
  RB_CK_CNT (rb);
}



void *
rbuf_get (rbuf_t * rb)
{
  int r;
  rbuf_elt_t * rbe = rb->rb_first;
  if (!rbe)
    return NULL;
  for (r = rbe->rbe_read; r != rbe->rbe_write; r = RBE_NEXT (rbe, r))
    {
      void * elt = rbe->rbe_data[r];
      if (elt)
	{
	  rb->rb_count--;
	  rbe->rbe_data[r] = NULL;
	  rbe->rbe_read = RBE_NEXT (rb, r);
	  if (0 == --rbe->rbe_count && rb->rb_first != rb->rb_last)
	    {
	      L2_DELETE (rb->rb_first, rb->rb_last, rbe, rbe_);
	      dk_free ((caddr_t)rbe, sizeof (rbuf_elt_t));
	      RBUF_TC (rbe_free_ctr);
	    }
	  RB_CK_CNT (rb);
	  return elt;
	}
    }
    return NULL;
}


void *
rbuf_first (rbuf_t * rb)
{
  int r;
  rbuf_elt_t * rbe = rb->rb_first;
  if (!rbe)
    return NULL;
  for (r = rbe->rbe_read; r != rbe->rbe_write; r = RBE_NEXT (rbe, r))
    {
      void * elt = rbe->rbe_data[r];
      if (elt)
	{
	  rbe->rbe_read = r;
	  return elt;
	}
    }
    return NULL;
}


int
rbe_merge_next (rbuf_elt_t * rbe, int delete_inx)
{
  /* copy the data from this rbe to the next, preserving order.  Return the place in the new next where the item just at the right of the delete will be so that an iteration over the rb does not hit elements twice */
  void * tmp[RBE_LEN];
  int inx, fill = 0;
  int skip = 0, before = 1;
  rbuf_elt_t * next = rbe->rbe_next;
  for (inx = rbe->rbe_read; inx != rbe->rbe_write; inx = RBE_NEXT (rbe, inx))
    {
      if (before && inx == delete_inx)
	before = 0;
      if (rbe->rbe_data[inx])
	{
	  tmp[fill++] = rbe->rbe_data[inx];
	  if (before)
	    skip++;
	}
    }
  for (inx = next->rbe_read; inx != next->rbe_write; inx = RBE_NEXT (next, inx))
    {
      if (next->rbe_data[inx])
	tmp[fill++] = next->rbe_data[inx];
    }
  if (fill != rbe->rbe_count + next->rbe_count) GPF_T1 ("bad rbe in rbe_merge_next");
  memcpy_16 (next->rbe_data, tmp, fill * sizeof (caddr_t));
  memzero (&rbe->rbe_data[fill], (RBE_LEN - fill) * sizeof (caddr_t));
  next->rbe_count += rbe->rbe_count;
  next->rbe_read = 0;
  next->rbe_write = fill;
  rbe->rbe_count = 0;
  return skip;
}


void
rbuf_delete (rbuf_t * rb, rbuf_elt_t * rbe, int * inx_ret)
{
  int inx = *inx_ret;
  rbe->rbe_data[inx] = NULL;
  rb->rb_count--;
  rbe->rbe_count--;
  if (rb->rb_first != rb->rb_last)
    {
      int skip = 0, next_merged = 0;
      if (rbe->rbe_next && rbe->rbe_count < RBE_LEN / 3 * 2 && rbe->rbe_count + rbe->rbe_next->rbe_count < RBE_LEN)
	{
	  skip = rbe_merge_next (rbe, inx);
	  next_merged = 1;
	}
      if (0 == rbe->rbe_count)
	{
	  L2_DELETE (rb->rb_first, rb->rb_last, rbe, rbe_);
	  dk_free ((caddr_t)rbe, sizeof (rbuf_elt_t));
	  RBUF_TC (rbe_free_ctr);
	  *inx_ret = next_merged ? -skip - 2 : -1; /* in DO_RBUF will jump to next rbe */
	}
      else
	if (inx == rbe->rbe_read)
	  rbe->rbe_read = RBE_NEXT (rbe, rbe->rbe_read);
      RB_CK_CNT (rb);
      return;
    }
  if (inx == rbe->rbe_read)
    rbe->rbe_read = RBE_NEXT (rbe, rbe->rbe_read);
  RB_CK_CNT (rb);
}


void
rbuf_delete_all (rbuf_t * rb)
{
  rbuf_elt_t * elt, *next;
  if (rb->rb_first)
    {
      rbuf_elt_t * rbe = rb->rb_first;
      if (rbe && rbe->rbe_read == rbe->rbe_write && !rbe->rbe_next)
	return;
      for (elt = rb->rb_first->rbe_next; elt; elt = next)
	{
	  next = elt->rbe_next;
	  dk_free ((caddr_t)elt, sizeof (rbuf_elt_t));
	  RBUF_TC (rbe_free_ctr);
	}
      rb->rb_first->rbe_next = NULL;
      rb->rb_last = rb->rb_first;
      rb->rb_first->rbe_count = 0;
      rb->rb_first->rbe_read = rb->rb_first->rbe_write = 0;
      memzero (&rb->rb_first->rbe_data, RBE_LEN * sizeof (caddr_t));
    }
  rb->rb_count = 0;
}

void
rbuf_destroy (rbuf_t * rb)
{
  if (rb->rb_free_func)
    {
      DO_RBUF (caddr_t, elt, rbe, rbe_inx, rb)
	{
	  rb->rb_free_func (elt);
	}
      END_DO_RBUF;
    }
  RB_CK_CNT (rb);
  rbuf_delete_all (rb);
  if (rb->rb_first)
    {
      dk_free ((caddr_t)rb->rb_first, sizeof (rbuf_elt_t));
      RBUF_TC (rbe_free_ctr);
    }
  rb->rb_first = rb->rb_last = NULL;
}


rbuf_t test_rbuf;

void
rbuf_test ()
{
  rbuf_t rb;
  int inx, ctr;
  int xx = 0;
  memset (&rb, 0, sizeof (rb));
  for (inx = 0; inx < 1000000; inx++)
    {
      rbuf_add (&rb, (void*) ((ptrlong)inx + 1));
    }
  for (inx = 0; inx < 1000000; inx++)
    {
      if ((ptrlong)rbuf_get (&rb) != inx + 1)
	GPF_T1 ("rbuf test 1");
    }
  rbuf_get  (&rb);
  for (ctr = 0; ctr < 100; ctr++)
    {
      for (inx = 0; inx < 100 + ctr * 30; inx++)
	rbuf_add (&rb, (void*)((ptrlong)inx + 1 + ctr));

      DO_RBUF (ptrlong, elt, rbe, rbinx, &rb)
	{
	  if (0 == (xx++ % 2))
	    rbuf_delete (&rb, rbe, &inx);
	}
      END_DO_RBUF;
      for (inx = 0; inx < 100 + ctr * 30; inx++)
	rbuf_get (&rb);
    }
  rbuf_delete_all (&rb);
  for (inx = 1; inx < 100000; inx++)
    rbuf_add (&rb, (void*)(ptrlong)inx);
  rbuf_rewrite (&rb);
  DO_RBUF (ptrlong, x, rbe, rbe_inx, &rb)
    {
      if (x > 1000 && x < 2000)
	continue;
      rbuf_keep (&rb, (void*)x);
    }
  END_DO_RBUF;
  rbuf_rewrite_done (&rb);
  if (rb.rb_count != 99000) GPF_T1 ("bad rewrite");
}


int
rbuf_free_cb (rbuf_t * rb)
{
  rbuf_destroy (rb);
  return 0;
}

rbuf_t *
rbuf_allocate ()
{
  return (rbuf_t*) dk_alloc_box_zero (sizeof (rbuf_t), DV_RBUF);
}


void
rbuf_append (rbuf_t * dest, rbuf_t * src)
{
  RB_CK_CNT (dest);
  if (!src->rb_count)
    return;
  if (src->rb_count < 10)
    {
      void *x;
      while ((x = rbuf_get (src)))
	rbuf_add (dest, x);
      return;
    }
  if (!dest->rb_count && dest->rb_first)
    {
      dk_free ((caddr_t)dest->rb_first, sizeof (rbuf_elt_t));
      RBUF_TC (rbe_free_ctr);
      dest->rb_first = src->rb_first;
      dest->rb_last = src->rb_last;
    }
  else if (dest->rb_last)
    {
      dest->rb_last->rbe_next = src->rb_first;
      src->rb_first->rbe_prev = dest->rb_last;
      dest->rb_last = src->rb_last;
    }
  else
    {
      dest->rb_first = src->rb_first;
      dest->rb_last = src->rb_last;
    }
  dest->rb_count += src->rb_count;
  src->rb_count = 0;
  src->rb_first = NULL;
  src->rb_last = NULL;
  RB_CK_CNT (dest);
}



void rbuf_rewrite (rbuf_t * rb)
{
  rb->rb_rewrite_last = rb->rb_first;
  rb->rb_rewrite = rb->rb_first->rbe_read;
}

void
rbuf_keep (rbuf_t * rb, void * elt)
{
  rbuf_elt_t * rbe = rb->rb_rewrite_last;
  int next = RBE_NEXT (rbe, rb->rb_rewrite);
  if (next == rbe->rbe_write)
    {
      rbe->rbe_count = RBE_LEN - 1;
      rbe = rb->rb_rewrite_last = rbe->rbe_next;
      rb->rb_rewrite = rbe->rbe_read;
    }
  rbe->rbe_data[rb->rb_rewrite] = elt;
  rb->rb_rewrite = next;
}


void
rbuf_rewrite_done (rbuf_t * rb)
{
#if 0
  rbuf_elt_t * last = rb->rb_rewrite_last;
  rbuf_elt_t * del = last, *next;
  rb->rb_count = 0;
  if (rb->rb_rewrite != last->rbe_read)
    {
      del = last->rbe_next;
      rb->rb_last = last;
      rb->rb_count = last->rbe_count = last->rb_rewrite > last->rbe_read ? rb->rb_rewrite - last->rbe_read : rb->rb_rewrite + (RBE_LEN - last->rbe_read);
      if (last->rbe_write > last->rbe_read)
	;
      else
	memzero (&last->rbe_data[last->rbe_write], sizeof (caddr_t) * (last->rbe_read - last->rbe_write));
      last->rbe_next = NULL;
    }
  else
    {
      if (last->rbe_prev)
	{
	  rb->rb_last = last->rbe_prev;
	  last->rbe_prev->rbe_next = NULL;
	}
      else
	last->rbe_count = 0;
      rb->rb_count = 0;
      return;
    }
  for (; del; del = next)
    {
      next = del->rbe_next;
      dk_free (del, sizeof (rbuf_elt_t));
    }
  for (elt = rb->rb_first; elt != rb->rb_last; elt = elt->rbe_next)
    rb->rb_count += RBE_LEN - 1;
  RB_CK_CNT (rb);
#endif
}

