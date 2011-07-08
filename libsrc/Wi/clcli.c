/*
 *  clcli.c
 *
 *  $Id$
 *
 *  Cluster client end
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2011 OpenLink Software
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
#include "sqlver.h"
#include "log.h"


#define oddp(x) ((x) & 1)

int32 cl_msg_drop_rate;
int32 cl_con_drop_rate;
int32 drop_seed;


int64
__gethash64 (int64 i, id_hash_t * ht)
{
  int64 r;
  gethash_64 (r, i, ht);
  return r;
}


cl_req_group_t *
cl_req_group (lock_trx_t * lt)
{
  cl_req_group_t * clrg = (cl_req_group_t*) dk_alloc_box_zero (sizeof (cl_req_group_t), DV_CLRG);;
  clrg->clrg_ref_count = 1;
  dk_mutex_init (&clrg->clrg_mtx, MUTEX_TYPE_SHORT);
  clrg->clrg_lt = lt;
  if (lt)
    clrg->clrg_trx_no = lt->lt_trx_no;
  return clrg;
}


void
clrg_set_lt (cl_req_group_t * clrg, lock_trx_t * lt)
{
  clrg->clrg_lt = lt;
  clrg->clrg_trx_no = lt ? lt->lt_trx_no : 0;
}

resource_t * clib_rc;


cll_in_box_t *
clib_allocate ()
{
  NEW_VARZ (cll_in_box_t, clib);
  return clib;
}


void
clib_clear (cll_in_box_t * clib)
{
  dk_session_t * strses = clib->clib_req_strses;
  memset (clib, 0, (ptrlong)&((cll_in_box_t*)0)->clib_in_strses);
  clib->clib_req_strses = strses;
  clib->clib_in_strses.dks_in_buffer = 0;
  clib->clib_in_strses.dks_in_fill = 0;
  clib->clib_in_strses.dks_in_read = 0;
  clib->clib_in_strses.dks_error = 0;
}


void
clib_free (cll_in_box_t * clib)
{
      dk_free ((caddr_t)clib, sizeof (cll_in_box_t));
}


void
clib_rc_init ()
{
  clib_rc = resource_allocate (200, (rc_constr_t)clib_allocate, (rc_destr_t)clib_free, (rc_destr_t)clib_clear, 0);
}


cl_req_group_t *
clrg_copy (cl_req_group_t * clrg)
{
  mutex_enter (clrg_ref_mtx);
  clrg->clrg_ref_count++;
  mutex_leave (clrg_ref_mtx);
  return clrg;
}



int
clrg_destroy (cl_req_group_t * clrg)
{
  mutex_enter (clrg_ref_mtx);
  clrg->clrg_ref_count--;
  if (clrg->clrg_ref_count)
    {
      mutex_leave (clrg_ref_mtx);
      return 1;
    }
  mutex_leave (clrg_ref_mtx);
  mutex_enter (local_cll.cll_mtx);
  mutex_enter (&clrg->clrg_mtx);
  DO_SET (cll_in_box_t *, clib, &clrg->clrg_clibs)
    {
      if (!clib->clib_req_no || clib->clib_fake_req_no)
	continue; /* if no req no or a dfg sending clib, it is not really registered. If freed here, would remhash using a remote clib no and could collide dropping a local registration */
#if 0
      if (gethash ((void*)(ptrlong)clib->clib_req_no, local_cll.cll_id_to_clib) != (void*)clib)
	GPF_T1 ("duplicate clib req no");
#endif
      remhash ((void*)(ptrlong)clib->clib_req_no, local_cll.cll_id_to_clib);
    }
  END_DO_SET();
  mutex_leave (local_cll.cll_mtx);
  mutex_leave (&clrg->clrg_mtx);
  dk_free_tree (clrg->clrg_error);
  DO_SET (cll_in_box_t *, clib, &clrg->clrg_clibs)
    {
      cl_message_t * cm;
      cl_op_t * clo;
      /* clear the basket but do not free, the items are from the clib_local_pool */
      while ((clo = (cl_op_t *) basket_get (&clib->clib_local_clo)));
      /* clear the basket but the content is freed in freeing the params of the ts */
      dk_free_tree ((caddr_t) clib->clib_first_row);
      switch (clib->clib_first.clo_op)
	{
	case CLO_ROW:
	  break;
	default:
	  clo_destroy (&clib->clib_first);
	}
      if (clib->clib_local_pool)
	mp_free (clib->clib_local_pool);

      resource_store (clib_rc, (void*)clib);
    }
  END_DO_SET ();
  dk_set_free (clrg->clrg_clibs);
  dk_mutex_destroy (&clrg->clrg_mtx);
  if (clrg->clrg_cu)
    cu_free (clrg->clrg_cu);
  if (clrg->clrg_pool)
    mp_free (clrg->clrg_pool);
  return 0;
}


cl_op_t *
clo_allocate (char op)
{
  cl_op_t * clo = dk_alloc_box_zero (sizeof (cl_op_t), DV_CLOP);
  clo->clo_op = op;
  return clo;
}

cl_op_t *
clo_allocate_2 (char op)
{
  cl_op_t * clo = dk_alloc_box_zero (sizeof (cl_op_t), DV_CLOP);
  clo->clo_op = op;
  return clo;
}

cl_op_t *
clo_allocate_3 (char op)
{
  cl_op_t * clo = dk_alloc_box_zero (sizeof (cl_op_t), DV_CLOP);
  clo->clo_op = op;
  return clo;
}

cl_op_t *
clo_allocate_4 (char op)
{
  cl_op_t * clo = dk_alloc_box_zero (sizeof (cl_op_t), DV_CLOP);
  clo->clo_op = op;
  return clo;
}

#define CLO_HEAD_SIZE ((ptrlong)&((cl_op_t*)0)->_)
#define CLO_ROW_SIZE (((ptrlong)&((cl_op_t*)0)->_.row.cols) + sizeof (caddr_t))
#define CLO_CALL_SIZE  (CLO_HEAD_SIZE + sizeof (((cl_op_t*)0)->_.call))


cl_op_t *
mp_clo_allocate (mem_pool_t * mp, char op)
{
  caddr_t box;
  cl_op_t * clo;
  switch (op)
    {
    case CLO_SET_END:
    case CLO_BATCH_END:
      MP_BYTES (box, mp, CLO_HEAD_SIZE);
      clo = (cl_op_t*) box;
      clo->clo_clibs = NULL;
      break;
    case CLO_ROW:
      MP_BYTES (box, mp, CLO_ROW_SIZE);
      clo = (cl_op_t*) box;
      clo->_.row.cols = NULL;
      clo->clo_clibs = NULL;
      break;
    case CLO_CALL:
      MP_BYTES (box, mp, CLO_CALL_SIZE);
      clo = (cl_op_t*) box;
      memset (clo, 0, CLO_CALL_SIZE);
            break;
    default:
      MP_BYTES (box, mp, sizeof (cl_op_t));
      clo = (cl_op_t*) box;
      memset (clo, 0, sizeof (cl_op_t));
    }
  clo->clo_pool = mp;
  clo->clo_op = op;
  return clo;
}
int
clo_destroy  (cl_op_t * clo)
{
  dk_set_free (clo->clo_clibs);
  switch (clo->clo_op)
    {
    case CLO_INSERT:
      if (clo->_.insert.rd)
	{
	  if (clo->_.insert.rd->rd_itc)
	    itc_free (clo->_.insert.rd->rd_itc);
	  rd_free (clo->_.insert.rd);
	}
      break;
    case CLO_DELETE:
      if (clo->_.delete.rd)
	{
	  if (clo->_.delete.rd->rd_itc)
	    itc_free (clo->_.delete.rd->rd_itc);
	  rd_free (clo->_.delete.rd);
	}
      break;
    case CLO_SELECT:
      if (clo->_.select.itc)
	itc_free (clo->_.select.itc);
      break;
    case CLO_SELECT_SAME:
      dk_free_tree ((caddr_t)clo->_.select_same.params);
      break;
    case CLO_ROW:
      dk_free_tree ((caddr_t)clo->_.row.cols);
      break;
    case CLO_ERROR:
      dk_free_tree ((caddr_t)clo->_.error.err);
      break;
    case CLO_ITCL:
      if (!clo->_.itcl.itcl)
	break;
      dk_free_box ((caddr_t) clo->_.itcl.itcl->itcl_clrg);
      mp_free (clo->_.itcl.itcl->itcl_pool);
      dk_free ((caddr_t)clo->_.itcl.itcl, sizeof (itc_cluster_t));
      break;
    case CLO_CALL:
      dk_free_tree (clo->_.call.func);
      dk_free_tree (clo->_.call.params);
      break;
    case CLO_STATUS:
      dk_free ((caddr_t)clo->_.cst.cst, sizeof (cl_status_t));
      break;
    case CLO_INXOP:
      dk_free (clo->_.inxop.cio, sizeof (cl_inxop_t));
      break;
    case CLO_QF_EXEC:
      dk_free_tree ((caddr_t)clo->_.frag.params);
      break;
    case CLO_STN_IN:
      dk_free_box (clo->_.stn_in.in);
      break;
    case CLO_DFG_ARRAY:
      dk_free_tree ((caddr_t)clo->_.dfg_array.stats);
      break;
    case CLO_DFG_STATE:
      dk_free_box ((caddr_t)clo->_.dfg_stat.out_counts);
      break;
    }
  return 0;
}



int
clrg_add (cl_req_group_t * clrg, cl_host_t * host, cl_op_t * clop)
{
  return 0;
}


int
clrg_wait (cl_req_group_t * clrg, int wait_all, caddr_t * qst)
{
  return CLE_OK;
}


void
clib_read_next (cll_in_box_t * clib, caddr_t * inst, dk_set_t out_slots)
{
  /* set clib_first to be the next from the in strings.  If no data, set it to CLO_NONE.
   * if the next is a row and the slots are given, set the data into the slots direct and set the row.cols to null */
  dtp_t op;
  dk_session_t * ses = &clib->clib_in_strses;
  if (clib->clib_host && clib->clib_host->ch_id == local_cll.cll_this_host)
    {
      if (++clib->clib_rows_done < clib->clib_n_local_rows)
	{
	  clib_row_boxes (clib);
	  return;
	}
      clib->clib_first.clo_op = CLO_NONE;
      return;
    }
}


void
cl_local_skip_to_set (cll_in_box_t * clib)
{
  while (clib->clib_in_parsed.bsk_count)
    {
      cl_op_t * clo = (cl_op_t *)basket_first (&clib->clib_in_parsed);
      if (CLO_ERROR == clo->clo_op)
	sqlr_resignal (clo->_.error.err);
      if (clo->clo_nth_param_row >= clib->clib_skip_target_set)
	return;
      basket_get (&clib->clib_in_parsed);
    }
  for (;;)
    {
      cl_op_t * clo = (cl_op_t*)basket_first (&clib->clib_local_clo);
      if (!clo)
	return;
      if (clo->clo_nth_param_row < clib->clib_skip_target_set)
	basket_get (&clib->clib_local_clo);
      else
	return;
    }
}
void
clib_more (cll_in_box_t * clib)
{
  if (clib->clib_host->ch_id == local_cll.cll_this_host)
    {
      if (clib->clib_skip_target_set)
	{
	  cl_local_skip_to_set (clib);
	  return; /* do not do an actual more when skipping sets.  Let the subsequen itcl_fetch do that. Like this, the state is not changed by skipping sets */
	}
      if (clib->clib_local_clo.bsk_count)
	clib_local_next (clib);
    }
}

cl_op_t *
clib_first (cll_in_box_t * clib)
{
 retry:
  if (clib->clib_host->ch_id == local_cll.cll_this_host)
    {
      if (!clib->clib_is_active)
	{
	  clib->clib_first.clo_op = CLO_SET_END;
	  return &clib->clib_first;
	}
      if (clib->clib_rows_done > clib->clib_n_local_rows)
	{
	  clib_more (clib);
	  goto retry;
	}
      clib->clib_rows_done = 0;
      clib_row_boxes (clib);
    }
  if (CLO_NONE == clib->clib_first.clo_op)
    {
      if (clib->clib_in.bsk_count)
	{
	  clib_read_next (clib, NULL, NULL);
	  return clib_first (clib);
	}
      return NULL;
    }
  if (CLO_BATCH_END == clib->clib_first.clo_op)
    {
      clib->clib_batches_read++;
      if (clib->clib_batches_requested == clib->clib_batches_read)
	{
	  cl_printf (("Host %d at batch end, unexpected, at %d rows\n", clib->clib_host->ch_id, clib->clib_rows_done));
	  clib_more (clib);
	}
      clib->clib_rows_done = 0;
      clib->clib_row_low_water = 0;
      clib->clib_first.clo_op = CLO_NONE;
      return NULL;
    }
  return &clib->clib_first;
}


