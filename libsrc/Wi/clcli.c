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
 *  Copyright (C) 1998-2017 OpenLink Software
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
#ifndef WIN32
#include "sys/socket.h"
#include "netdb.h"
#include "netinet/tcp.h"
#endif

#define oddp(x) ((x) & 1)

int32 cl_msg_drop_rate;
int32 cl_con_drop_rate;
int32 drop_seed;


resource_t * clib_rc;


cll_in_box_t *
clib_allocate ()
{
  B_NEW_VARZ (cll_in_box_t, clib);
  return clib;
}


void
clib_clear (cll_in_box_t * clib)
{
  dk_session_t * strses = clib->clib_req_strses;
  cl_queue_t clq = clib->clib_in;
  assert (!clq.rb_count);
  rb_ck_cnt (&clq);
  memzero (clib, (ptrlong) & ((cll_in_box_t *) 0)->clib_in_strses);
  clib->clib_in = clq;
  clib->clib_req_strses = strses;
  clib->clib_in_strses.dks_in_buffer = 0;
  clib->clib_in_strses.dks_in_fill = 0;
  clib->clib_in_strses.dks_in_read = 0;
  clib->clib_in_strses.dks_error = 0;
}


void
clib_free (cll_in_box_t * clib)
{
#ifdef CL_RBUF
  rbuf_destroy (&clib->clib_in);
#endif
      dk_free ((caddr_t)clib, sizeof (cll_in_box_t));
}


void
clib_rc_init ()
{
  clib_rc = resource_allocate (200, (rc_constr_t)clib_allocate, (rc_destr_t)clib_free, (rc_destr_t)clib_clear, 0);
}

dk_mutex_t mctr_mtx;
dk_hash_64_t *mctr_ht;
uint32 mctr_ctr;

msg_ctr_t *
mctr_by_id (uint64 id)
{
  ptrlong pmctr;
  mutex_enter (&mctr_mtx);
  gethash_64 (pmctr, id, mctr_ht);
  if (pmctr)
    {
      mutex_leave (&mctr_mtx);
      return (msg_ctr_t *) pmctr;
    }
  {
    NEW_VARZ (msg_ctr_t, mctr);
    sethash_64 (id, mctr_ht, (ptrlong) mctr);
    mctr->mctr_conn_id = id;
    mutex_leave (&mctr_mtx);
    return mctr;
  }
}


msg_ctr_t *
mctr_new_conn (cl_host_t * to)
{
  int64 id;
  NEW_VARZ (msg_ctr_t, mctr);
  mutex_enter (&mctr_mtx);
  id = ++mctr_ctr;
  id |= ((uint64) local_cll.cll_this_host) << 48;
  id |= ((uint64) to->ch_id) << 32;
  sethash_64 (id, mctr_ht, (ptrlong) mctr);
  mutex_leave (&mctr_mtx);
  mctr->mctr_conn_id = id;
  return mctr;
}


void
mctr_init ()
{
  mctr_ht = hash_table_allocate_64 (200);
  dk_mutex_init (&mctr_mtx, MUTEX_TYPE_SHORT);
}




void
id_hash_print (id_hash_t * ht)
{
  DO_IDHASH (void *, k, void *, d, ht)
  {
    printf ("%p -> %p\n", k, d);
  }
  END_DO_IDHASH;
}

void
ht_print (dk_hash_t * ht)
{
  DO_HT (void *, k, void *, d, ht)
  {
    printf ("%p -> %p\n", k, d);
  }
  END_DO_HT;
}


int64
__gethash64 (int64 i, id_hash_t * ht)
{
  int64 r;
  gethash_64 (r, i, ht);
  return r;
}


void
__dk_hash_64_print (id_hash_t * ht)
{
  DO_IDHASH (int64, k, int64, d, ht)
  {
    printf ("%d:%d -> " BOXINT_FMTX "\n", QFID_HOST (k), (uint32) k, d);
  }
  END_DO_IDHASH;
}

cl_req_group_t *
cl_req_group (lock_trx_t * lt)
{
  cl_req_group_t *clrg = (cl_req_group_t *) dk_alloc_box_zero (sizeof (cl_req_group_t), DV_CLRG);
  clrg->clrg_ref_count = 1;
  dk_mutex_init (&clrg->clrg_mtx, MUTEX_TYPE_SHORT);
  clrg->clrg_lt = lt;
  if (lt)
    clrg->clrg_trx_no = lt->lt_main_trx_no ? lt->lt_main_trx_no : lt->lt_trx_no;
  return clrg;
}


void
clrg_set_lt (cl_req_group_t * clrg, lock_trx_t * lt)
{
  clrg->clrg_lt = lt;
  clrg->clrg_trx_no = lt ? (lt->lt_main_trx_no ? lt->lt_main_trx_no : lt->lt_trx_no) : 0;
}

cl_req_group_t *
clrg_copy (cl_req_group_t * clrg)
{
  mutex_enter (&clrg->clrg_mtx);
  clrg->clrg_ref_count++;
  mutex_leave (&clrg->clrg_mtx);
  return clrg;
}



void
clrg_dml_free (cl_req_group_t * clrg)
{
  /* drop allocd mem for daq ins/del */
  DO_SET (cl_op_t *, clo, &clrg->clrg_vec_clos)
  {
    caddr_t *params = NULL;
    if (CLO_INSERT == clo->clo_op || CLO_DELETE == clo->clo_op)
      params = clo->_.insert.rd->rd_values;
    else if (CLO_CALL == clo->clo_op)
      params = clo->_.call.params;
    if (params)
      {
	int inx;
	DO_BOX (data_col_t *, dc, inx, params)
	{
	  if (DV_DATA == DV_TYPE_OF (dc))
	    dc_reset (dc);
	}
	END_DO_BOX;
      }
  }
  END_DO_SET ();
  clrg->clrg_vec_clos = NULL;
}


void lt_alt_trx_no_free (lock_trx_t * lt, int64 alt_no);


#define TA_DUP_CANCEL 1300


int
cl_is_dup_cancel (id_hash_t ** ht, int to_host, int coord, int req_no)
{
  int64 id;
  id_hash_t *dups;
  if (!*ht)
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      dups = (id_hash_t *) THR_ATTR (self, TA_DUP_CANCEL);
      if (dups)
	*ht = dups;
      else
	{
	  *ht = dups = id_hash_allocate (123, sizeof (int64), 0, boxint_hash, boxint_hashcmp);
	  SET_THR_ATTR (self, TA_DUP_CANCEL, dups);
	}
    }
  else
    dups = *ht;
  if (boxint_hash != dups->ht_hash_func || 8 != dups->ht_ext_inx)
    GPF_T1 ("corrupt dups cancel ht");
  id = DFG_ID (((to_host << 16) | coord), req_no);
  if (id_hash_get (dups, (caddr_t) & id))
    return 1;
  id_hash_set (dups, (caddr_t) & id, NULL);
  return 0;
}

void
cl_clear_dup_cancel ()
{
}



int
clrg_destroy (cl_req_group_t * clrg)
{
  id_hash_t *dups = NULL;
  mutex_enter (&clrg->clrg_mtx);
  clrg->clrg_ref_count--;
  if (clrg->clrg_ref_count)
    {
      mutex_leave (&clrg->clrg_mtx);
      return 1;
    }
  mutex_leave (&clrg->clrg_mtx);
  IN_CLL;
  mutex_enter (&clrg->clrg_mtx);
  DO_SET (cll_in_box_t *, clib, &clrg->clrg_clibs)
    {
    if (clib->clib_alt_trx_no)
      lt_alt_trx_no_free (clrg->clrg_lt, clib->clib_alt_trx_no);
      if (!clib->clib_req_no || clib->clib_fake_req_no)
	continue; /* if no req no or a dfg sending clib, it is not really registered. If freed here, would remhash using a remote clib no and could collide dropping a local registration */
#if 0
      if (gethash ((void*)(ptrlong)clib->clib_req_no, local_cll.cll_id_to_clib) != (void*)clib)
	GPF_T1 ("duplicate clib req no");
#endif
      remhash ((void*)(ptrlong)clib->clib_req_no, local_cll.cll_id_to_clib);
    }
  END_DO_SET();
  LEAVE_CLL;
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
  clrg_dml_free (clrg);
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
      clo->_.row.local_dcs = NULL;
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
    }
  return 0;
}



int
clrg_add (cl_req_group_t * clrg, cl_host_t * host, cl_op_t * clop)
{
  return 0;
}

int
clrg_add_slice (cl_req_group_t * clrg, cl_host_t * host, cl_op_t * clop, slice_id_t slid)
{
  return 0;
}


extern du_thread_t *recomp_thread;

int
clrg_wait (cl_req_group_t * clrg, int wait_all, caddr_t * qst)
	{
  return CLE_OK;
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
lt_alt_trx_no_free (lock_trx_t * lt, int64 alt_no)
{
}

void
clrg_top_check (cl_req_group_t * clrg, query_instance_t * top_qi)
	{
}
