/*
 *  $Id$
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
#include "qncache.h"
qn_cache_t *qc_root;

qc_result_t *
qc_lookup (uint32 clslice, caddr_t qckey)
{
  id_hash_t *res;
  qc_result_t **place, *qcr;
  mutex_enter (&qcr_ref_mtx);
  res = (id_hash_t *) gethash (DP_ADDR2VOID (clslice), qc_root->qc_slices);
  if (!res)
    {
      res = id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      sethash (DP_ADDR2VOID (clslice), qc_root->qc_slices, (void *) res);
    }
  place = (qc_result_t **) id_hash_get (res, (caddr_t) & qckey);
  if (!place)
    {
      qcr = dk_alloc_box_zero (sizeof (qc_result_t), DV_QC_RESULT);
      qcr->qcr_ref_count = 1;
      qcr->qcr_slice = clslice;
      qcr->qcr_key = qckey;
      qcr->qcr_status = QCR_BUILDING;
      qcr->qcr_mp = mem_pool_alloc ();
      id_hash_set (res, (caddr_t) & qckey, (caddr_t) & qcr);
      mutex_leave (&qcr_ref_mtx);
      return qcr;
    }
  else
    {
      qcr = *place;
      dk_free_tree (qckey);
      if (QCR_BUILDING == qcr->qcr_status)
	{
	  mutex_leave (&qcr_ref_mtx);
	  return NULL;
	}
      qcr->qcr_ref_count++;
      mutex_leave (&qcr_ref_mtx);
      return qcr;
    }
}


dk_mutex_t qcr_ref_mtx;

qc_result_t *
qcr_copy (qc_result_t * qcr)
{
  mutex_enter (&qcr_ref_mtx);
  qcr->qcr_ref_count++;
  mutex_leave (&qcr_ref_mtx);
  return qcr;
}


int
qcr_free (qc_result_t * qcr)
{
  id_hash_t *ht;
  mutex_enter (&qcr_ref_mtx);
  qcr->qcr_ref_count--;
  if (qcr->qcr_ref_count)
    {
      mutex_leave (&qcr_ref_mtx);
      return 1;
    }
  if (QCR_READY == qcr->qcr_status && 0 == qcr->qcr_ref_count)
    {
      mutex_leave (&qcr_ref_mtx);
      return 1;
    }

  ht = (id_hash_t *) gethash ((void *) (ptrlong) qcr->qcr_slice, qc_root->qc_slices);
  id_hash_remove (ht, (caddr_t) & qcr->qcr_key);
  mutex_leave (&qcr_ref_mtx);
  dk_free_tree (qcr->qcr_key);
  if (qcr->qcr_mp)
    mp_free (qcr->qcr_mp);
  return 0;
}


void
qc_init ()
{
  qc_root = (qn_cache_t *) dk_alloc (sizeof (qn_cache_t));
  qc_root->qc_slices = hash_table_allocate (101);
  dk_mem_hooks (DV_QC_RESULT, (box_copy_f) qcr_copy, (box_destr_f) qcr_free, 0);
  dk_mutex_init (&qcr_ref_mtx, MUTEX_TYPE_SHORT);
}
