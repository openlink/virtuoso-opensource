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
 *  Copyright (C) 1998-2012 OpenLink Software
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


