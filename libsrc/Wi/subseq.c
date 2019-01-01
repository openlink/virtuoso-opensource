/*
 *  $Id$
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
#include "sqlbif.h"
#include "subseq.h"

static int
ss_search_item (caddr_t * arr, caddr_t item)
{
  int inx;
  DO_BOX (caddr_t, el, inx, arr)
    {
      if (el == item)
	return inx;
    }
  END_DO_BOX;
  return -1;
}

static int
ss_advance (subseq_t * iter, int adv_idx)
{
  if (adv_idx < 0)
    return -1;
  else
    {
      int curr_arr_idx =
	  ss_search_item (iter->ss_array, iter->ss_state[adv_idx]);
      int advanced = 0;
      if (-1 == curr_arr_idx)
	GPF_T;
      while (curr_arr_idx >=
	  iter->ss_in_state_num + iter->ss_out_state_num - 1)
	{
	  advanced = 1;
	  if (-1 == ss_advance (iter, adv_idx - 1))
	    return -1;
	  curr_arr_idx =
	      ss_search_item (iter->ss_array,
		  iter->ss_state[adv_idx - 1]) + 1;
	  if (curr_arr_idx == iter->ss_in_state_num + iter->ss_out_state_num - 1)
	    break;
	  if (-1 == curr_arr_idx)
	    GPF_T;
	}
      if (!advanced)
	curr_arr_idx++;
      iter->ss_state[adv_idx] = iter->ss_array[curr_arr_idx];
    }
  return 1;
}


subseq_t *
ss_iter_init (caddr_t * init_array, int in_num)
{
  NEW_VARZ (subseq_t, ss);
  ss->ss_array = init_array;
  ss->ss_in_state_num = in_num;
  ss->ss_out_state_num = BOX_ELEMENTS (init_array) - in_num;
  return ss;
}

caddr_t *
ss_iter_next (subseq_t * iter)
{
  if (!iter->ss_state)
    {
      int inx;
      iter->ss_state = (caddr_t *) dk_alloc_box (
	  iter->ss_in_state_num * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      _DO_BOX (inx, iter->ss_state)
	{
	  iter->ss_state[inx] = iter->ss_array[inx];
	}
      END_DO_BOX;
      return iter->ss_state;
    }
  if (-1 == ss_advance (iter, iter->ss_in_state_num - 1))
    return 0;
  return iter->ss_state;
}


caddr_t *
ss_not_in_seq (subseq_t * iter)
{
  int inx;
  caddr_t * ns = iter->ss_not_in_state;
  int ns_idx = 0;
  if (!ns)
    ns = iter->ss_not_in_state = (caddr_t *) dk_alloc_box (
	iter->ss_out_state_num * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  DO_BOX (caddr_t, item, inx, iter->ss_array)
    {
      int inx2;
      DO_BOX (caddr_t, item2, inx2, iter->ss_state)
	{
	  if (item == item2)
	    break;
	}
      END_DO_BOX;
      if (inx2 != BOX_ELEMENTS (iter->ss_state))
	continue;
      ns[ns_idx++] = item;
    }
  END_DO_BOX;
  return ns;
}

void
ss_iter_free (subseq_t * ss_iter)
{
  dk_free_box ((box_t) ss_iter->ss_state);
  dk_free_box ((box_t) ss_iter->ss_not_in_state);
}

#if 0
caddr_t
ss_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *test_arr;
  dk_set_t test_ll = 0;
  int inx;
  int nn;

  dk_set_push (&test_ll, box_num (0));
  dk_set_push (&test_ll, box_num (1));
  dk_set_push (&test_ll, box_num (2));
  /*  dk_set_push (&test_ll, box_num (3));
      dk_set_push (&test_ll, box_num (4));
      dk_set_push (&test_ll, box_num (5));
      dk_set_push (&test_ll, box_num (6));
      dk_set_push (&test_ll, box_num (7)); */

  test_ll = dk_set_nreverse (test_ll);
  test_arr = (caddr_t*) dk_set_to_array (test_ll);
  dk_set_free (test_ll);

  DO_BOX (caddr_t, nn, inx, test_arr)
    {
      printf ("->%ld\n", unbox (nn));
    }
  END_DO_BOX;
  printf ("=<=\n");

    {
      subseq_t *ss = ss_iter_init (test_arr, 2);
      caddr_t *res;
      while ((res = ss_iter_next (ss)))
	{
	  caddr_t * res2;
	  DO_BOX (caddr_t, nn, inx, res)
	    {
	      printf ("%ld,", unbox (nn));
	    }
	  END_DO_BOX;
	  printf ("\t");
	  res2 = ss_not_in_seq (ss);
	  DO_BOX (caddr_t, nn, inx, res2)
	    {
	      printf ("%ld,", unbox (nn));
	    }
	  END_DO_BOX;
	  printf ("\n");
	  fflush (stdout);
	}
    }
    {
      subseq_t *ss = ss_iter_init (test_arr, 1);
      caddr_t *res;
      while ((res = ss_iter_next (ss)))
	{
	  caddr_t * res2;
	  DO_BOX (caddr_t, nn, inx, res)
	    {
	      printf ("%ld,", unbox (nn));
	    }
	  END_DO_BOX;
	  printf ("\t");
	  res2 = ss_not_in_seq (ss);
	  DO_BOX (caddr_t, nn, inx, res2)
	    {
	      printf ("%ld,", unbox (nn));
	    }
	  END_DO_BOX;
	  printf ("\n");
	  fflush (stdout);
	}
    }
    {
      subseq_t *ss = ss_iter_init (test_arr, 0);
      caddr_t *res;
      while ((res = ss_iter_next (ss)))
	{
	  caddr_t * res2;
	  DO_BOX (caddr_t, nn, inx, res)
	    {
	      printf ("%ld,", unbox (nn));
	    }
	  END_DO_BOX;
	  printf ("\t");
	  res2 = ss_not_in_seq (ss);
	  DO_BOX (caddr_t, nn, inx, res2)
	    {
	      printf ("%ld,", unbox (nn));
	    }
	  END_DO_BOX;
	  printf ("\n");
	  fflush (stdout);
	}
    }

  return 0;
    {
      subseq_t *ss = ss_iter_init (test_arr, 5);
      caddr_t *res;
      while ((res = ss_iter_next (ss)))
	{
	  caddr_t * res2;
	  DO_BOX (caddr_t, nn, inx, res)
	    {
	      printf ("%ld,", unbox (nn));
	    }
	  END_DO_BOX;
	  printf ("\t");
	  res2 = ss_not_in_seq (ss);
	  DO_BOX (caddr_t, nn, inx, res2)
	    {
	      printf ("%ld,", unbox (nn));
	    }
	  END_DO_BOX;
	  printf ("\n");
	  fflush (stdout);
	}
    }
  fflush (stdout);
  return 0;

}
#endif
