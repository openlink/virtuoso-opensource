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

#ifndef _QNCACHE_H
#define _QNCACHE_H

/* query result cache */

typedef struct qc_result_s
{
  int qcr_ref_count;
  char qcr_status;
  uint32 qcr_slice;
  int qcr_fill;
  caddr_t qcr_key;
  data_col_t **qcr_result;
  id_hash_t *qcr_reverse;
  mem_pool_t *qcr_mp;
} qc_result_t;


/* qcr_state */
#define QCR_BUILDING 1
#define QCR_READY 2


typedef struct qn_cache_s
{
  dk_hash_t *qc_slices;
} qn_cache_t;


#define DV_QC_RESULT  143

extern qn_cache_t *qnc_root;
extern dk_mutex_t qcr_ref_mtx;

qc_result_t *qc_lookup (uint32 clslice, caddr_t qckey);
void qc_init ();
extern qn_cache_t *root_qc;

#endif
